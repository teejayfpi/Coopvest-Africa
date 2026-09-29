// Supabase Edge Function: process-contribution-reminders
// Cron job that runs daily to check and send contribution reminders.
//
// This function used to query `user_settings` for `user_id`, `fcm_token`,
// `preferred_day` and `monthly_amount` — none of which exist on that table
// (`user_settings` is keyed by `profile_id` and holds preferences only). The
// query therefore failed every run, so the cron silently did nothing while the
// client-side reminder kept inventing an "overdue" notice.
//
// The real sources are:
//   profiles      — contribution_method, preferred_payment_day, monthly_amount, created_at
//   device_tokens — token (active FCM token), active
//   contributions — status + contribution_month (the month paid FOR)
//   savings       — last_savings_date (wallet deposits never write a row above)
//
// A member counts as paid for the current month when EITHER a `successful`
// contribution row carries this month in `contribution_month`, OR
// `savings.last_savings_date` falls in this month. Members who joined this
// month are never overdue. This mirrors `hasPaidThisSavingsMonth` in
// `backend/src/routes/wallet.js` so push and in-app agree.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY");

const PAID_STATUSES = new Set(["successful", "adjusted"]);

function monthKey(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
}

/** True when `value` (a date or timestamp) falls in `date`'s calendar month. */
function isSameMonth(value: string | null | undefined, date: Date): boolean {
  if (!value) return false;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return false;
  return (
    parsed.getFullYear() === date.getFullYear() &&
    parsed.getMonth() === date.getMonth()
  );
}

serve(async (_req: Request) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: members, error: membersError } = await supabase
      .from("profiles")
      .select(
        "id, contribution_method, preferred_payment_day, monthly_amount, created_at",
      )
      .eq("contribution_method", "manual");

    if (membersError) {
      throw new Error(`Failed to fetch members: ${membersError.message}`);
    }

    if (!members || members.length === 0) {
      return json({ message: "No manual contribution members found", sent: 0 });
    }

    const profileIds = members.map((m) => m.id);

    const [{ data: tokens }, { data: paidContributions }, { data: savings }] =
      await Promise.all([
        supabase
          .from("device_tokens")
          .select("profile_id, token")
          .eq("active", true)
          .in("profile_id", profileIds),
        supabase
          .from("contributions")
          .select("profile_id, contribution_month, status")
          .in("profile_id", profileIds),
        supabase
          .from("savings")
          .select("profile_id, last_savings_date")
          .in("profile_id", profileIds),
      ]);

    const tokensByProfile = new Map<string, string[]>();
    for (const row of tokens ?? []) {
      if (!row.token) continue;
      const list = tokensByProfile.get(row.profile_id) ?? [];
      list.push(row.token);
      tokensByProfile.set(row.profile_id, list);
    }

    const now = new Date();
    const currentMonth = monthKey(now);
    const dayOfMonth = now.getDate();

    const paidByProfile = new Set<string>();
    for (const c of paidContributions ?? []) {
      if (PAID_STATUSES.has(c.status) && c.contribution_month === currentMonth) {
        paidByProfile.add(c.profile_id);
      }
    }
    const savingsByProfile = new Map(
      (savings ?? []).map((s) => [s.profile_id, s.last_savings_date]),
    );

    const reminders: Array<{
      userId: string;
      fcmToken: string;
      title: string;
      body: string;
      type: string;
    }> = [];

    for (const member of members) {
      // No registered device — sending would be pointless.
      const deviceTokens = tokensByProfile.get(member.id) ?? [];
      if (deviceTokens.length === 0) continue;

      const paidThisMonth =
        paidByProfile.has(member.id) ||
        isSameMonth(savingsByProfile.get(member.id), now);
      const joinedThisMonth = isSameMonth(member.created_at, now);
      if (paidThisMonth || joinedThisMonth) continue;

      const preferredDay = member.preferred_payment_day || 0;
      const amount = (member.monthly_amount ?? 0).toLocaleString();

      let notification:
        | { title: string; body: string; type: string }
        | null = null;

      if (preferredDay === dayOfMonth) {
        notification = {
          title: "Contribution Due Today",
          body: `You haven't made your monthly contribution of ₦${amount} yet. Pay today!`,
          type: "contribution_due_today",
        };
      } else if (preferredDay === dayOfMonth + 3) {
        notification = {
          title: "Contribution Reminder",
          body: `Your monthly contribution of ₦${amount} is due in 3 days.`,
          type: "contribution_reminder",
        };
      } else if (preferredDay < dayOfMonth) {
        const daysOverdue = dayOfMonth - preferredDay;
        notification = {
          title: "Contribution Overdue",
          body: `Your contribution of ₦${amount} is ${daysOverdue} day${daysOverdue > 1 ? "s" : ""} overdue!`,
          type: "contribution_overdue",
        };
      }

      if (!notification) continue;

      // One push per device so a member with several tokens is not missed.
      for (const token of deviceTokens) {
        reminders.push({ userId: member.id, fcmToken: token, ...notification });
      }
    }

    if (reminders.length === 0 || !FCM_SERVER_KEY) {
      return json({
        message: "No reminders needed",
        totalMembers: members.length,
        remindersSent: 0,
      });
    }

    const sent = await sendFcmNotifications(reminders);
    return json({
      success: true,
      totalMembers: members.length,
      remindersSent: sent,
      reminders,
    });
  } catch (error) {
    console.error("Error processing reminders:", error);
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function sendFcmNotifications(reminders: any[]): Promise<number> {
  if (!FCM_SERVER_KEY) return 0;

  let sentCount = 0;

  for (const reminder of reminders) {
    try {
      const response = await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${FCM_SERVER_KEY}`,
        },
        body: JSON.stringify({
          to: reminder.fcmToken,
          notification: {
            title: reminder.title,
            body: reminder.body,
            sound: "default",
            badge: "1",
          },
          data: {
            type: reminder.type,
            userId: reminder.userId,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "savings_notifications",
              sound: "default",
            },
          },
        }),
      });

      const result = await response.json();
      if (result.success === 1) {
        sentCount++;
      }
    } catch (error) {
      console.error(`Failed to send to ${reminder.userId}:`, error);
    }
  }

  return sentCount;
}
