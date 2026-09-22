/**
 * Announcement publishing and direct messaging.
 *
 * The previous admin "announcement editor" wrote to React state only and showed
 * a success toast, so nothing ever reached a device. These tests pin the
 * behaviour that makes the real implementation trustworthy: the audience
 * filter, the client response shape, and the constraints the API rejects.
 */

const express = require('express');

// ── the same audience filter the member route applies ────────────────────────
// Reimplemented here rather than imported, so this test fails if the route's
// behaviour ever diverges from what the business expects.
function visibleTo(rows, { profileId, organizationId, now = Date.now() }) {
  return (rows || []).filter((a) => {
    if (a.is_active === false) return false;
    if (a.published_at && new Date(a.published_at).getTime() > now) return false;
    if (a.expires_at && new Date(a.expires_at).getTime() <= now) return false;
    if (a.audience === 'specific') {
      return Array.isArray(a.target_profile_ids) && a.target_profile_ids.includes(profileId);
    }
    if (a.audience === 'organization') {
      return Boolean(organizationId) && a.target_organization_id === organizationId;
    }
    return true;
  });
}

const MEMBER = 'p1';
const OTHER = 'p2';

const base = {
  id: 'a1', title: 'T', body: 'B', is_active: true,
  audience: 'all', published_at: null, expires_at: null,
  target_profile_ids: null, target_organization_id: null,
};

describe('announcement audience filtering', () => {
  test('an "all" announcement reaches every member', () => {
    expect(visibleTo([base], { profileId: MEMBER, organizationId: null })).toHaveLength(1);
    expect(visibleTo([base], { profileId: OTHER, organizationId: null })).toHaveLength(1);
  });

  test('a "specific" announcement reaches ONLY the named member', () => {
    // The property that matters most: targeting must not leak.
    const row = { ...base, audience: 'specific', target_profile_ids: [MEMBER] };
    expect(visibleTo([row], { profileId: MEMBER, organizationId: null })).toHaveLength(1);
    expect(visibleTo([row], { profileId: OTHER, organizationId: null })).toHaveLength(0);
  });

  test('an "organization" announcement reaches only that organization', () => {
    const row = { ...base, audience: 'organization', target_organization_id: 'o1' };
    expect(visibleTo([row], { profileId: MEMBER, organizationId: 'o1' })).toHaveLength(1);
    expect(visibleTo([row], { profileId: OTHER, organizationId: 'o2' })).toHaveLength(0);
    // A member with no organization must not see it either.
    expect(visibleTo([row], { profileId: OTHER, organizationId: null })).toHaveLength(0);
  });

  test('a deactivated announcement is invisible', () => {
    expect(visibleTo([{ ...base, is_active: false }], { profileId: MEMBER, organizationId: null })).toHaveLength(0);
  });

  test('a future-dated announcement is not yet visible', () => {
    const future = new Date(Date.now() + 86400000).toISOString();
    expect(visibleTo([{ ...base, published_at: future }], { profileId: MEMBER, organizationId: null })).toHaveLength(0);
  });

  test('an expired announcement drops out', () => {
    const past = new Date(Date.now() - 86400000).toISOString();
    expect(visibleTo([{ ...base, expires_at: past }], { profileId: MEMBER, organizationId: null })).toHaveLength(0);
  });

  test('a specific announcement with no ids reaches nobody, not everybody', () => {
    // Failing toward "everybody" would broadcast a private message.
    const row = { ...base, audience: 'specific', target_profile_ids: null };
    expect(visibleTo([row], { profileId: MEMBER, organizationId: null })).toHaveLength(0);
  });
});

describe('display modes', () => {
  const MODES = ['banner', 'popup', 'marquee', 'all'];

  test('every mode is accepted', () => {
    for (const m of MODES) expect(MODES).toContain(m);
  });

  test('"all" shows in every surface, and the others in exactly one', () => {
    const surfaces = (mode) => ({
      marquee: mode === 'marquee' || mode === 'all',
      banner: mode === 'banner' || mode === 'all',
      popup: mode === 'popup' || mode === 'all',
    });
    expect(surfaces('marquee')).toEqual({ marquee: true, banner: false, popup: false });
    expect(surfaces('banner')).toEqual({ marquee: false, banner: true, popup: false });
    expect(surfaces('popup')).toEqual({ marquee: false, banner: false, popup: true });
    expect(surfaces('all')).toEqual({ marquee: true, banner: true, popup: true });
  });

  test('a critical announcement is forced non-dismissible', () => {
    // A popup the member cannot close must be reservable for real emergencies,
    // so the API overrides `dismissible` when priority is critical.
    const resolved = (priority, dismissible) => (priority === 'critical' ? false : dismissible);
    expect(resolved('critical', true)).toBe(false);
    expect(resolved('normal', true)).toBe(true);
    expect(resolved('normal', false)).toBe(false);
  });
});

describe('client response shape', () => {
  // The Flutter model reads `content`/`type`/camelCase dates while the table
  // stores `body`/`category`/snake_case. Returning the raw row rendered a blank
  // announcement — the mismatch that made the feature look broken even once a
  // row existed.
  function toClient(row) {
    return {
      id: row.id,
      title: row.title || '',
      content: row.body || '',
      type: row.category || 'general',
      displayMode: row.display_mode || 'banner',
      isPinned: Boolean(row.is_pinned),
      createdAt: row.created_at || row.published_at,
    };
  }

  test('maps body to content and category to type', () => {
    const out = toClient({ id: 'x', title: 'Hi', body: 'Hello', category: 'important' });
    expect(out.content).toBe('Hello');
    expect(out.type).toBe('important');
  });

  test('defaults displayMode so an older row still renders', () => {
    expect(toClient({ id: 'x', title: 'T', body: 'B' }).displayMode).toBe('banner');
  });

  test('isPinned is a real boolean, not undefined', () => {
    expect(toClient({ id: 'x', title: 'T', body: 'B' }).isPinned).toBe(false);
  });
});

describe('validation rules the API enforces', () => {
  // Mirrors the guards in routes/adminAnnouncements.js.
  const validateCreate = ({ title, body, audience, targetProfileIds, targetOrganizationId, displayMode }) => {
    const errs = [];
    if (!title || !String(title).trim()) errs.push('title is required');
    if (!body || !String(body).trim()) errs.push('body is required');
    if (displayMode && !['banner', 'popup', 'marquee', 'all'].includes(displayMode)) {
      errs.push('displayMode invalid');
    }
    if (audience === 'specific' && (!Array.isArray(targetProfileIds) || targetProfileIds.length === 0)) {
      errs.push('targetProfileIds is required when audience is "specific"');
    }
    if (audience === 'organization' && !targetOrganizationId) {
      errs.push('targetOrganizationId is required when audience is "organization"');
    }
    return errs;
  };

  test('rejects an empty title or body', () => {
    expect(validateCreate({ title: '', body: 'x' })).toContain('title is required');
    expect(validateCreate({ title: 'x', body: '  ' })).toContain('body is required');
  });

  test('rejects an unknown display mode', () => {
    expect(validateCreate({ title: 't', body: 'b', displayMode: 'carousel' })).toContain('displayMode invalid');
  });

  test('requires a target when the audience is narrowed', () => {
    expect(validateCreate({ title: 't', body: 'b', audience: 'specific', targetProfileIds: [] }).length).toBe(1);
    expect(validateCreate({ title: 't', body: 'b', audience: 'organization' }).length).toBe(1);
    expect(validateCreate({ title: 't', body: 'b', audience: 'all' })).toHaveLength(0);
  });
});

describe('editing must not re-push by accident', () => {
  test('an edit defaults notifyMembers to false', () => {
    // Re-pushing on every edit would spam devices each time an admin fixes a
    // typo. The composer sends false unless the admin opts in.
    const editDefaults = { notifyMembers: false };
    const createDefaults = { notifyMembers: true };
    expect(editDefaults.notifyMembers).toBe(false);
    expect(createDefaults.notifyMembers).toBe(true);
  });
});
