-- 030: Allow the mobile 'payment_proof_approved' notification type.
--
-- The instant Paystack settlement (payments.js → notifyService.notifyPaymentProofApproved)
-- needs to store the rich event type so the Flutter realtime listener can branch
-- on it (dashboard refresh on payment_proof_approved). The old CHECK only allowed
-- the coarse bucket types, so this richer type had to be added explicitly.
--
-- Safe to re-run: drops and recreates the CHECK with the new value added.

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type IN (
      'transaction','savings','investment','loan','referral',
      'kyc','system','promotion','security','reminder',
      'payment_proof_approved'
    )
  );