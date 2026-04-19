/**
 * Supabase-backed model helper
 *
 * Tiny compatibility shim that gives the rest of the codebase a Mongoose-ish
 * API (`find`, `findOne`, `findById`, `create`, `updateOne`, `countDocuments`,
 * `deleteOne`, instance `save()`) on top of a Supabase table. Keeps the route
 * handlers almost unchanged while routing every read/write through Postgres.
 *
 * Only the subset of Mongoose features actually used by this codebase is
 * implemented. Aggregations are handled with explicit SQL / RPC where needed.
 */

const supabase = require('../config/supabase');
const logger = require('../utils/logger');

/**
 * Translate a Mongoose-style filter into a Supabase `.match()` / `.in()` /
 * `.or()` chain. Only equality, `$in`, `$ne`, `$gt(e)`, `$lt(e)`, `$regex`
 * and `$or` are supported.
 */
function applyFilter(query, filter = {}) {
  const { $or, $and, ...rest } = filter;

  for (const [key, value] of Object.entries(rest)) {
    if (value === undefined) continue;

    if (value && typeof value === 'object' && !Array.isArray(value) && !(value instanceof Date)) {
      if ('$in' in value) query = query.in(key, value.$in);
      else if ('$ne' in value) query = query.neq(key, value.$ne);
      else if ('$gt' in value) query = query.gt(key, value.$gt);
      else if ('$gte' in value) query = query.gte(key, value.$gte);
      else if ('$lt' in value) query = query.lt(key, value.$lt);
      else if ('$lte' in value) query = query.lte(key, value.$lte);
      else if ('$regex' in value) query = query.ilike(key, `%${value.$regex}%`);
      else if ('$exists' in value) {
        query = value.$exists ? query.not(key, 'is', null) : query.is(key, null);
      } else {
        query = query.eq(key, value);
      }
    } else {
      query = query.eq(key, value);
    }
  }

  if (Array.isArray($or) && $or.length > 0) {
    const clauses = $or.map((sub) => {
      const [k, v] = Object.entries(sub)[0];
      if (v && typeof v === 'object' && '$regex' in v) return `${k}.ilike.%${v.$regex}%`;
      return `${k}.eq.${v}`;
    });
    query = query.or(clauses.join(','));
  }

  return query;
}

class Query {
  constructor(table, filter = {}, { mapRow, mapRowBack } = {}) {
    this.table = table;
    this.filter = filter;
    this._mapRow = mapRow || ((r) => r);
    this._mapRowBack = mapRowBack || ((r) => r);
    this._sort = null;
    this._limit = null;
    this._offset = null;
    this._select = '*';
  }

  select(fields) { this._select = typeof fields === 'string' ? fields : '*'; return this; }
  sort(spec) { this._sort = spec; return this; }
  limit(n) { this._limit = n; return this; }
  skip(n) { this._offset = n; return this; }
  lean() { return this; }
  populate() { return this; }

  async _execute({ single = false, count = false } = {}) {
    let q = supabase.from(this.table).select(this._select, count ? { count: 'exact' } : undefined);
    q = applyFilter(q, this.filter);

    if (this._sort) {
      if (typeof this._sort === 'string') {
        for (const part of this._sort.split(' ')) {
          const desc = part.startsWith('-');
          const col = desc ? part.slice(1) : part;
          q = q.order(col, { ascending: !desc });
        }
      } else {
        for (const [col, dir] of Object.entries(this._sort)) {
          q = q.order(col, { ascending: dir !== -1 });
        }
      }
    }

    if (this._limit != null) q = q.limit(this._limit);
    if (this._offset != null && this._limit != null) {
      q = q.range(this._offset, this._offset + this._limit - 1);
    }

    if (single) q = q.maybeSingle();

    const { data, error, count: total } = await q;
    if (error && error.code !== 'PGRST116') throw error;
    if (count) return { data: (data || []).map(this._mapRow), count: total || 0 };
    if (single) return data ? this._mapRow(data) : null;
    return (data || []).map(this._mapRow);
  }

  then(onFulfilled, onRejected) {
    return this._execute().then(onFulfilled, onRejected);
  }
}

function defineModel({ table, mapRow, mapRowBack, defaults }) {
  const _mapRow = mapRow || ((r) => r);
  const _mapRowBack = mapRowBack || ((r) => r);
  const _defaults = defaults || (() => ({}));

  class Instance {
    constructor(data = {}) {
      Object.assign(this, _defaults(), data);
    }

    async save() {
      const row = _mapRowBack({ ..._defaults(), ...this });
      const hasId = row.id != null;
      let res;
      if (hasId) {
        res = await supabase.from(table).update(row).eq('id', row.id).select().maybeSingle();
      } else {
        res = await supabase.from(table).insert(row).select().maybeSingle();
      }
      if (res.error) throw res.error;
      Object.assign(this, _mapRow(res.data));
      return this;
    }

    toObject() { return { ...this }; }
    toJSON() { return { ...this }; }
  }

  Instance.find = (filter = {}) => new Query(table, filter, { mapRow: _mapRow, mapRowBack: _mapRowBack });

  Instance.findOne = async (filter = {}) => {
    const q = new Query(table, filter, { mapRow: _mapRow, mapRowBack: _mapRowBack });
    return q._execute({ single: true });
  };

  Instance.findById = async (id) => {
    const { data, error } = await supabase.from(table).select('*').eq('id', id).maybeSingle();
    if (error && error.code !== 'PGRST116') throw error;
    return data ? Object.assign(new Instance(), _mapRow(data)) : null;
  };

  Instance.findByIdAndUpdate = async (id, update, opts = {}) => {
    const patch = _mapRowBack(update.$set || update);
    const { data, error } = await supabase.from(table).update(patch).eq('id', id).select().maybeSingle();
    if (error) throw error;
    if (opts.new === false) return null;
    return data ? Object.assign(new Instance(), _mapRow(data)) : null;
  };

  Instance.findByIdAndDelete = async (id) => {
    const { data, error } = await supabase.from(table).delete().eq('id', id).select().maybeSingle();
    if (error && error.code !== 'PGRST116') throw error;
    return data ? _mapRow(data) : null;
  };

  Instance.findOneAndUpdate = async (filter, update, opts = {}) => {
    const existing = await Instance.findOne(filter);
    if (!existing) {
      if (opts.upsert) return Instance.create({ ...filter, ...(update.$set || update) });
      return null;
    }
    const patch = _mapRowBack(update.$set || update);
    const { data, error } = await supabase.from(table).update(patch).eq('id', existing.id).select().maybeSingle();
    if (error) throw error;
    return data ? Object.assign(new Instance(), _mapRow(data)) : null;
  };

  Instance.updateOne = async (filter, update) => {
    const existing = await Instance.findOne(filter);
    if (!existing) return { matchedCount: 0, modifiedCount: 0 };
    const patch = _mapRowBack(update.$set || update);
    const { error } = await supabase.from(table).update(patch).eq('id', existing.id);
    if (error) throw error;
    return { matchedCount: 1, modifiedCount: 1 };
  };

  Instance.updateMany = async (filter, update) => {
    const patch = _mapRowBack(update.$set || update);
    let q = supabase.from(table).update(patch);
    q = applyFilter(q, filter);
    const { error, count } = await q.select('id', { count: 'exact' });
    if (error) throw error;
    return { matchedCount: count || 0, modifiedCount: count || 0 };
  };

  Instance.deleteOne = async (filter) => {
    const existing = await Instance.findOne(filter);
    if (!existing) return { deletedCount: 0 };
    const { error } = await supabase.from(table).delete().eq('id', existing.id);
    if (error) throw error;
    return { deletedCount: 1 };
  };

  Instance.deleteMany = async (filter = {}) => {
    let q = supabase.from(table).delete();
    q = applyFilter(q, filter);
    const { error, count } = await q.select('id', { count: 'exact' });
    if (error) throw error;
    return { deletedCount: count || 0 };
  };

  Instance.create = async (data) => {
    const row = _mapRowBack({ ..._defaults(), ...data });
    const { data: inserted, error } = await supabase.from(table).insert(row).select().maybeSingle();
    if (error) throw error;
    return Object.assign(new Instance(), _mapRow(inserted));
  };

  Instance.countDocuments = async (filter = {}) => {
    let q = supabase.from(table).select('id', { count: 'exact', head: true });
    q = applyFilter(q, filter);
    const { error, count } = await q;
    if (error) throw error;
    return count || 0;
  };

  Instance.table = table;
  Instance._mapRow = _mapRow;
  Instance._mapRowBack = _mapRowBack;

  return Instance;
}

module.exports = { defineModel, applyFilter, supabase, logger };
