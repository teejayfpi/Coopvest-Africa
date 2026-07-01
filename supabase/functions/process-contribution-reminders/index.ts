// Supabase Edge Function: process-contribution-reminders
// Cron job that runs daily to check and send contribution reminders

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY");

interface UserContributionData {
  userId: string;
  fcmToken: string;
  contributionMethod: string;
  preferredDay: number;
  monthlyAmount: number;
  hasContributedThisMonth: boolean;
  lastContributionDate: string | null;
}

serve(async (req: Request) => {
  try {
    // Create Supabase client with service role to bypass RLS
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get all users with manual contribution method
    const { data: users, error: usersError } = await supabase
      .from("user_settings") // Adjust table name based on your schema
      .select("user_id, fcm_token, contribution_method, preferred_day, monthly_amount")
      .eq("contribution_method", "manual");

    if (usersError) {
      throw new Error(`Failed to fetch users: ${usersError.message}`);
    }

    if (!users || users.length === 0) {
      return new Response(
        JSON.stringify({ message: "No manual contribution users found", sent: 0 }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    const today = new Date();
    const dayOfMonth = today.getDate();
    const reminders = [];

    for (const user of users as UserContributionData[]) {
      if (!user.fcm_token) continue;

      // Check if this is the user's contribution day
      const isDueToday = user.preferred_day === dayOfMonth;
      const isDueIn3Days = user.preferred_day === dayOfMonth + 3;
      const isOverdue = user.preferred_day < dayOfMonth && !user.has_contributed_this_month;

      let notification: { title: string; body: string; type: string } | null = null;

      if (isDueToday) {
        notification = {
          title: "Contribution Due Today",
          body: `You haven't made your monthly contribution of ₦${user.monthly_amount?.toLocaleString()} yet. Pay today!`,
          type: "contribution_due_today",
        };
      } else if (isDueIn3Days) {
        notification = {
          title: "Contribution Reminder",
          body: `Your monthly contribution of ₦${user.monthly_amount?.toLocaleString()} is due in 3 days.`,
          type: "contribution_reminder",
        };
      } else if (isOverdue) {
        const daysOverdue = dayOfMonth - (user.preferred_day || 0);
        notification = {
          title: "Contribution Overdue",
          body: `Your contribution of ₦${user.monthly_amount?.toLocaleString()} is ${daysOverdue} day${daysOverdue > 1 ? "s" : ""} overdue!`,
          type: "contribution_overdue",
        };
      }

      if (notification) {
        reminders.push({
          userId: user.user_id,
          fcmToken: user.fcm_token,
          ...notification,
        });
      }
    }

    // Send FCM notifications
    if (reminders.length > 0 && FCM_SERVER_KEY) {
      const sent = await sendFcmNotifications(reminders);
      console.log(`Sent ${sent} contribution reminders`);

      return new Response(
        JSON.stringify({
          success: true,
          totalUsers: users.length,
          remindersSent: sent,
          reminders,
        }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        message: "No reminders needed",
        totalUsers: users.length,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error processing reminders:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

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
