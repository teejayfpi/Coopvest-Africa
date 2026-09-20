-- 042_seed_organizations.sql
--
-- Seeds the partner-employer list that backs the salary-deduction picker.
--
-- WHY THIS IS NEEDED
-- ------------------
-- `GET /organizations/selectable` filters on `status = 'active'` AND
-- `deduction_enabled = true`. Production had ZERO rows in `organizations`, so
-- every salary-deduction member saw an empty employer picker and could not
-- complete KYC at all — the picker's "Organization is required" validator had
-- nothing to match against. Members could only fall back to
-- "Request my employer".
--
-- SCOPE
-- -----
-- Only `name`, `code`, `type`, `deduction_enabled` and `status` are set. The
-- remittance columns (bank name, account number, reference hint) are
-- deliberately left NULL: those are commercial details per employer and must
-- be filled in by finance before real payroll is processed. Seeding a
-- placeholder account number would be worse than leaving it empty, because it
-- could be used to send money to the wrong place.
--
-- `deduction_enabled = true` is therefore a statement that the employer is
-- selectable, NOT that remittance is configured. Admins should review this
-- list and set remittance details (or disable) per employer before payroll
-- runs. Until then the member can still register and choose their employer.
--
-- Idempotent: guarded on `code`, and uses ON CONFLICT DO NOTHING so re-running
-- against an already-seeded database is a no-op and never clobbers an admin's
-- edits to a name or remittance detail.

-- Codes are the stable handle finance quotes on remittance advice.
-- 'uni_' = university, 'bank_' = bank, 'corp_' = private company.

-- Idempotency note: `code` carries a PARTIAL unique index
-- (idx_organizations_code ... WHERE code IS NOT NULL), and PostgreSQL cannot
-- infer a partial index from a bare `ON CONFLICT (code)`. Rather than depend on
-- that inference, the insert is guarded with NOT EXISTS on the code, which is
-- equivalent, works against the partial index, and cannot fail on replay.
INSERT INTO public.organizations (name, code, type, deduction_enabled, status, is_active)
SELECT v.name, v.code, v.type, TRUE, 'active', TRUE
FROM (VALUES
  -- ── Federal universities ──────────────────────────────────────────────
  ('University of Ibadan', 'uni_ui', 'university'),
  ('University of Lagos', 'uni_unilag', 'university'),
  ('Obafemi Awolowo University', 'uni_oau', 'university'),
  ('University of Nigeria, Nsukka', 'uni_unn', 'university'),
  ('Ahmadu Bello University', 'uni_abu', 'university'),
  ('University of Benin', 'uni_uniben', 'university'),
  ('University of Ilorin', 'uni_unilorin', 'university'),
  ('University of Calabar', 'uni_unical', 'university'),
  ('University of Jos', 'uni_unijos', 'university'),
  ('University of Maiduguri', 'uni_unimaid', 'university'),
  ('University of Port Harcourt', 'uni_uniport', 'university'),
  ('Bayero University Kano', 'uni_buk', 'university'),
  ('Federal University of Technology, Akure', 'uni_futa', 'university'),
  ('Federal University of Technology, Minna', 'uni_futminna', 'university'),
  ('Federal University of Technology, Owerri', 'uni_futo', 'university'),
  ('Nnamdi Azikiwe University', 'uni_unizik', 'university'),
  ('University of Abuja', 'uni_uniabuja', 'university'),
  ('Federal University, Oye-Ekiti', 'uni_fuoye', 'university'),
  ('Federal University, Ndufu-Alike', 'uni_funai', 'university'),
  ('Michael Okpara University of Agriculture', 'uni_mouau', 'university'),
  ('Federal University of Agriculture, Abeokuta', 'uni_funaab', 'university'),
  ('University of Uyo', 'uni_uniuyo', 'university'),
  ('Modibbo Adama University', 'uni_mau', 'university'),

  -- ── State universities ────────────────────────────────────────────────
  ('Ladoke Akintola University of Technology', 'uni_lautech', 'university'),
  ('Lagos State University', 'uni_lasu', 'university'),
  ('Olabisi Onabanjo University', 'uni_oou', 'university'),
  ('Adekunle Ajasin University', 'uni_aaaua', 'university'),
  ('Ekiti State University', 'uni_eksu', 'university'),
  ('Delta State University', 'uni_delsu', 'university'),
  ('Ambrose Alli University', 'uni_aauekpoma', 'university'),
  ('Rivers State University', 'uni_rsu', 'university'),
  ('Enugu State University of Science and Technology', 'uni_esut', 'university'),
  ('Nasarawa State University', 'uni_nsuk', 'university'),
  ('Kaduna State University', 'uni_kasu', 'university'),
  ('Kano University of Science and Technology', 'uni_kust', 'university'),
  ('Ondo State University of Science and Technology', 'uni_osustech', 'university'),
  ('Tai Solarin University of Education', 'uni_tasued', 'university'),
  ('Abia State University', 'uni_absu', 'university'),
  ('Imo State University', 'uni_imsu', 'university'),
  ('Anambra State University', 'uni_ansu', 'university'),
  ('Benue State University', 'uni_bsum', 'university'),
  ('Kogi State University', 'uni_ksu', 'university'),
  ('Osun State University', 'uni_uniosun', 'university'),

  -- ── Private universities (incl. the ones named by the client) ─────────
  ('Bowen University, Iwo', 'uni_bowen', 'university'),
  ('Bowen University Teaching Hospital', 'uni_bowenoth', 'university'),
  ('Nigeria Baptist Theological Seminary, Ogbomoso', 'uni_nbts', 'university'),
  ('Covenant University', 'uni_covenant', 'university'),
  ('Babcock University', 'uni_babcock', 'university'),
  ('Lagos Business School', 'uni_lbs', 'university'),
  ('American University of Nigeria', 'uni_aun', 'university'),
  ('Afe Babalola University', 'uni_abuad', 'university'),
  ('Bells University of Technology', 'uni_bells', 'university'),
  ('Redeemer''s University', 'uni_run', 'university'),
  ('Ajayi Crowther University', 'uni_acu', 'university'),
  ('Lead City University', 'uni_lcu', 'university'),
  ('Igbinedion University', 'uni_iuokada', 'university'),
  ('Madonna University', 'uni_madonna', 'university'),
  ('Nigerian Turkish Nile University', 'uni_ntnu', 'university'),
  ('Baze University', 'uni_baze', 'university'),
  ('Elizade University', 'uni_elizade', 'university'),
  ('Adeleke University', 'uni_adeleke', 'university'),
  ('Joseph Ayo Babalola University', 'uni_jabu', 'university'),
  ('Salem University', 'uni_salem', 'university'),
  ('Landmark University', 'uni_landmark', 'university'),
  ('Pan-Atlantic University', 'uni_pau', 'university'),
  ('Augustine University', 'uni_augustine', 'university'),
  ('Chrisland University', 'uni_chrisland', 'university'),
  ('Mountain Top University', 'uni_mtu', 'university'),
  ('Anchor University', 'uni_anchor', 'university'),
  ('Trinity University', 'uni_trinity', 'university'),
  ('Hallmark University', 'uni_hallmark', 'university'),
  ('Rhema University', 'uni_rhema', 'university'),
  ('Wellspring University', 'uni_wellspring', 'university'),

  -- ── Banks ─────────────────────────────────────────────────────────────
  ('Access Bank', 'bank_access', 'bank'),
  ('Citibank Nigeria', 'bank_citibank', 'bank'),
  ('Ecobank Nigeria', 'bank_ecobank', 'bank'),
  ('Fidelity Bank', 'bank_fidelity', 'bank'),
  ('First Bank of Nigeria', 'bank_firstbank', 'bank'),
  ('First City Monument Bank (FCMB)', 'bank_fcmb', 'bank'),
  ('Guaranty Trust Bank (GTBank)', 'bank_gtbank', 'bank'),
  ('Heritage Bank', 'bank_heritage', 'bank'),
  ('Keystone Bank', 'bank_keystone', 'bank'),
  ('Polaris Bank', 'bank_polaris', 'bank'),
  ('Providus Bank', 'bank_providus', 'bank'),
  ('Stanbic IBTC Bank', 'bank_stanbic', 'bank'),
  ('Standard Chartered Bank Nigeria', 'bank_stanchart', 'bank'),
  ('Sterling Bank', 'bank_sterling', 'bank'),
  ('SunTrust Bank Nigeria', 'bank_suntrust', 'bank'),
  ('Union Bank of Nigeria', 'bank_union', 'bank'),
  ('United Bank for Africa (UBA)', 'bank_uba', 'bank'),
  ('Unity Bank', 'bank_unity', 'bank'),
  ('Wema Bank', 'bank_wema', 'bank'),
  ('Zenith Bank', 'bank_zenith', 'bank'),
  ('Jaiz Bank', 'bank_jaiz', 'bank'),
  ('Lotus Bank', 'bank_lotus', 'bank'),
  ('Optimism Bank', 'bank_optimism', 'bank'),
  ('Parallex Bank', 'bank_parallex', 'bank'),
  ('Premium Trust Bank', 'bank_premiumtrust', 'bank'),
  ('Signature Bank', 'bank_signature', 'bank'),
  ('Taj Bank', 'bank_taj', 'bank'),

  -- ── Private companies (major employers) ───────────────────────────────
  ('Dangote Group', 'corp_dangote', 'company'),
  ('MTN Nigeria', 'corp_mtn', 'company'),
  ('Airtel Nigeria', 'corp_airtel', 'company'),
  ('Globacom', 'corp_glo', 'company'),
  ('9mobile', 'corp_9mobile', 'company'),
  ('Nestlé Nigeria', 'corp_nestle', 'company'),
  ('Unilever Nigeria', 'corp_unilever', 'company'),
  ('Nigerian Breweries', 'corp_nb', 'company'),
  ('Guinness Nigeria', 'corp_guinness', 'company'),
  ('Flour Mills of Nigeria', 'corp_flourmills', 'company'),
  ('Nigerian Bottling Company', 'corp_nbc', 'company'),
  ('Coca-Cola Hellenic Bottling Company', 'corp_cchbc', 'company'),
  ('PZ Cussons Nigeria', 'corp_pz', 'company'),
  ('Cadbury Nigeria', 'corp_cadbury', 'company'),
  ('Honeywell Group', 'corp_honeywell', 'company'),
  ('Julius Berger Nigeria', 'corp_juliusberger', 'company'),
  ('Total Energies Nigeria', 'corp_total', 'company'),
  ('Shell Nigeria', 'corp_shell', 'company'),
  ('Chevron Nigeria', 'corp_chevron', 'company'),
  ('ExxonMobil Nigeria', 'corp_exxonmobil', 'company'),
  ('NNPC Limited', 'corp_nnpc', 'company'),
  ('First Exploration and Petroleum Development Company', 'corp_firstepd', 'company'),
  ('Seplat Energy', 'corp_seplat', 'company'),
  ('Oando Plc', 'corp_oando', 'company'),
  ('Nigerian National Petroleum Development Company', 'corp_nnpdc', 'company'),
  ('Deloitte Nigeria', 'corp_deloitte', 'company'),
  ('KPMG Nigeria', 'corp_kpmg', 'company'),
  ('PricewaterhouseCoopers (PwC) Nigeria', 'corp_pwc', 'company'),
  ('Ernst & Young (EY) Nigeria', 'corp_ey', 'company'),
  ('Accenture Nigeria', 'corp_accenture', 'company'),
  ('Andela', 'corp_andela', 'company'),
  ('Flutterwave', 'corp_flutterwave', 'company'),
  ('Paystack', 'corp_paystack', 'company'),
  ('OPay', 'corp_opay', 'company'),
  ('PalmPay', 'corp_palmpay', 'company'),
  ('Kuda Bank', 'corp_kuda', 'company'),
  ('Moniepoint', 'corp_moniepoint', 'company'),
  ('IHS Towers Nigeria', 'corp_ihs', 'company'),
  ('Shoprite Nigeria', 'corp_shoprite', 'company'),
  ('Jumia Nigeria', 'corp_jumia', 'company'),
  ('Konga', 'corp_konga', 'company'),
  ('Interswitch', 'corp_interswitch', 'company'),
  ('SystemSpecs', 'corp_systemspecs', 'company'),
  ('Hyundai Motors Nigeria', 'corp_hyundai', 'company'),
  ('Toyota Nigeria (CFAO)', 'corp_toyota', 'company'),
  ('Elizade Nigeria', 'corp_elizade', 'company'),
  ('Mikano International', 'corp_mikano', 'company'),
  ('BUA Group', 'corp_bua', 'company'),
  ('Lafarge Africa', 'corp_lafarge', 'company'),
  ('Berger Paints Nigeria', 'corp_berger', 'company'),
  ('Chi Limited', 'corp_chi', 'company'),
  ('FrieslandCampina WAMCO', 'corp_friesland', 'company'),
  ('Grand Cereals', 'corp_grandcereals', 'company'),
  ('Fan Milk Nigeria', 'corp_fanmilk', 'company'),
  ('UAC of Nigeria', 'corp_uac', 'company'),
  ('May & Baker Nigeria', 'corp_maybaker', 'company'),
  ('Emzor Pharmaceutical', 'corp_emzor', 'company'),
  ('Fidson Healthcare', 'corp_fidson', 'company'),
  ('GlaxoSmithKline Nigeria', 'corp_gsk', 'company'),
  ('FBN Holdings', 'corp_fbnholdings', 'company'),
  ('Africa Prudential', 'corp_africaprudential', 'company'),
  ('Nigerian Exchange Group', 'corp_nxgroup', 'company'),
  ('Central Securities Clearing System', 'corp_cscs', 'company'),
  ('Leadway Assurance', 'corp_leadway', 'company'),
  ('AXA Mansard', 'corp_axamansard', 'company'),
  ('AIICO Insurance', 'corp_aiico', 'company'),
  ('Mutual Benefits Assurance', 'corp_mutualbenefits', 'company'),
  ('NEM Insurance', 'corp_nem', 'company'),
  ('Custodian Investment', 'corp_custodian', 'company'),
  ('Wapic Insurance', 'corp_wapic', 'company'),
  ('Cornerstone Insurance', 'corp_cornerstone', 'company'),
  ('Sovereign Trust Insurance', 'corp_sovereigntrust', 'company'),
  ('Prestige Assurance', 'corp_prestige', 'company'),
  ('Consolidated Hallmark Insurance', 'corp_consolidatedhallmark', 'company'),
  ('LASACO Assurance', 'corp_lasaco', 'company'),
  ('Regency Alliance Insurance', 'corp_regency', 'company'),
  ('Veritas Kapital Assurance', 'corp_veritas', 'company'),
  ('SUNU Assurances Nigeria', 'corp_sunu', 'company'),
  ('Linkage Assurance', 'corp_linkage', 'company'),
  ('Universal Insurance', 'corp_universalinsurance', 'company'),
  ('Continental Reinsurance', 'corp_continentalre', 'company'),
  ('Africa Reinsurance Corporation', 'corp_africare', 'company'),

  -- ── Government / public sector ────────────────────────────────────────
  ('Federal Ministry of Finance', 'gov_fmf', 'government'),
  ('Federal Ministry of Education', 'gov_fme', 'government'),
  ('Federal Ministry of Health', 'gov_fmh', 'government'),
  ('Federal Inland Revenue Service (FIRS)', 'gov_firs', 'government'),
  ('Nigeria Customs Service', 'gov_customs', 'government'),
  ('National Identity Management Commission (NIMC)', 'gov_nimc', 'government'),
  ('National Pension Commission (PenCom)', 'gov_pencom', 'government'),
  ('Joint Admissions and Matriculation Board (JAMB)', 'gov_jamb', 'government'),
  ('National Youth Service Corps (NYSC)', 'gov_nysc', 'government'),
  ('Nigerian Communications Commission (NCC)', 'gov_ncc', 'government'),
  ('Nigerian National Petroleum Corporation Limited', 'gov_nnpcl', 'government'),
  ('Central Bank of Nigeria', 'gov_cbn', 'government'),
  ('Nigerian Ports Authority', 'gov_npa', 'government'),
  ('Federal Road Safety Corps (FRSC)', 'gov_frsc', 'government'),
  ('Nigerian Immigration Service', 'gov_nis', 'government'),
  ('Nigeria Police Force', 'gov_npf', 'government'),
  ('Nigerian Army', 'gov_army', 'government'),
  ('Nigerian Navy', 'gov_navy', 'government'),
  ('Nigerian Air Force', 'gov_airforce', 'government'),
  ('Nigerian Correctional Service', 'gov_ncs', 'government')
) AS v(name, code, type)
WHERE v.code IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.organizations o WHERE o.code = v.code
  );

-- Report what the picker will now offer, so the deploy log shows the effect.
DO $$
DECLARE
  v_total INTEGER;
  v_enabled INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_total FROM public.organizations;
  SELECT COUNT(*) INTO v_enabled
  FROM public.organizations
  WHERE status = 'active' AND deduction_enabled = TRUE;

  RAISE NOTICE 'organizations: % total, % selectable by members', v_total, v_enabled;
  RAISE NOTICE 'REMINDER: remittance bank details are NULL for seeded rows. Set them (or set deduction_enabled = FALSE) before real payroll remits.';
END $$;