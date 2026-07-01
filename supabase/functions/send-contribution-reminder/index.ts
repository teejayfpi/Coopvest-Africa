// Supabase Edge Function: send-contribution-reminder
// Sends FCM push notifications for contribution reminders

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY");

interface ReminderData {
  userId: string;
  fcmToken: string;
  title: string;
  body: string;
  type: string;
  data?: Record<string, string>;
}

serve(async (req: Request) => {
  try {
    const { reminders } = await req.json();

    if (!reminders || !Array.isArray(reminders)) {
      return new Response(
        JSON.stringify({ error: "Invalid request: reminders array required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!FCM_SERVER_KEY) {
      return new Response(
        JSON.stringify({ error: "FCM_SERVER_KEY not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const results = [];

    for (const reminder of reminders as ReminderData[]) {
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
              ...reminder.data,
            },
            android: {
              priority: "high",
              notification: {
                channelId: "savings_notifications",
                sound: "default",
                priority: "high",
              },
            },
          }),
        });

        const result = await response.json();
        results.push({
          userId: reminder.userId,
          success: result.success === 1,
          messageId: result.results?.[0]?.message_id,
        });
      } catch (error) {
        results.push({
          userId: reminder.userId,
          success: false,
          error: error.message,
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        results,
        sent: results.filter((r) => r.success).length,
        failed: results.filter((r) => !r.success).length,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
