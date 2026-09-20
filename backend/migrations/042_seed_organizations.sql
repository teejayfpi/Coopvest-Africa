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

INSERT INTO public.organizations (name, code, type, deduction_enabled, status)
VALUES
  -- ── Federal universities ──────────────────────────────────────────────
  ('University of Ibadan', 'uni_ui', 'university', TRUE, 'active'),
  ('University of Lagos', 'uni_unilag', 'university', TRUE, 'active'),
  ('Obafemi Awolowo University', 'uni_oau', 'university', TRUE, 'active'),
  ('University of Nigeria, Nsukka', 'uni_unn', 'university', TRUE, 'active'),
  ('Ahmadu Bello University', 'uni_abu', 'university', TRUE, 'active'),
  ('University of Benin', 'uni_uniben', 'university', TRUE, 'active'),
  ('University of Ilorin', 'uni_unilorin', 'university', TRUE, 'active'),
  ('University of Calabar', 'uni_unical', 'university', TRUE, 'active'),
  ('University of Jos', 'uni_unijos', 'university', TRUE, 'active'),
  ('University of Maiduguri', 'uni_unimaid', 'university', TRUE, 'active'),
  ('University of Port Harcourt', 'uni_uniport', 'university', TRUE, 'active'),
  ('Bayero University Kano', 'uni_buk', 'university', TRUE, 'active'),
  ('Federal University of Technology, Akure', 'uni_futa', 'university', TRUE, 'active'),
  ('Federal University of Technology, Minna', 'uni_futminna', 'university', TRUE, 'active'),
  ('Federal University of Technology, Owerri', 'uni_futo', 'university', TRUE, 'active'),
  ('Nnamdi Azikiwe University', 'uni_unizik', 'university', TRUE, 'active'),
  ('University of Abuja', 'uni_uniabuja', 'university', TRUE, 'active'),
  ('Federal University, Oye-Ekiti', 'uni_fuoye', 'university', TRUE, 'active'),
  ('Federal University, Ndufu-Alike', 'uni_funai', 'university', TRUE, 'active'),
  ('Michael Okpara University of Agriculture', 'uni_mouau', 'university', TRUE, 'active'),
  ('Federal University of Agriculture, Abeokuta', 'uni_funaab', 'university', TRUE, 'active'),
  ('University of Uyo', 'uni_uniuyo', 'university', TRUE, 'active'),
  ('Modibbo Adama University', 'uni_mau', 'university', TRUE, 'active'),

  -- ── State universities ────────────────────────────────────────────────
  ('Ladoke Akintola University of Technology', 'uni_lautech', 'university', TRUE, 'active'),
  ('Lagos State University', 'uni_lasu', 'university', TRUE, 'active'),
  ('Olabisi Onabanjo University', 'uni_oou', 'university', TRUE, 'active'),
  ('Adekunle Ajasin University', 'uni_aaaua', 'university', TRUE, 'active'),
  ('Ekiti State University', 'uni_eksu', 'university', TRUE, 'active'),
  ('Delta State University', 'uni_delsu', 'university', TRUE, 'active'),
  ('Ambrose Alli University', 'uni_aauekpoma', 'university', TRUE, 'active'),
  ('Rivers State University', 'uni_rsu', 'university', TRUE, 'active'),
  ('Enugu State University of Science and Technology', 'uni_esut', 'university', TRUE, 'active'),
  ('Nasarawa State University', 'uni_nsuk', 'university', TRUE, 'active'),
  ('Kaduna State University', 'uni_kasu', 'university', TRUE, 'active'),
  ('Kano University of Science and Technology', 'uni_kust', 'university', TRUE, 'active'),
  ('Ondo State University of Science and Technology', 'uni_osustech', 'university', TRUE, 'active'),
  ('Tai Solarin University of Education', 'uni_tasued', 'university', TRUE, 'active'),
  ('Abia State University', 'uni_absu', 'university', TRUE, 'active'),
  ('Imo State University', 'uni_imsu', 'university', TRUE, 'active'),
  ('Anambra State University', 'uni_ansu', 'university', TRUE, 'active'),
  ('Benue State University', 'uni_bsum', 'university', TRUE, 'active'),
  ('Kogi State University', 'uni_ksu', 'university', TRUE, 'active'),
  ('Osun State University', 'uni_uniosun', 'university', TRUE, 'active'),

  -- ── Private universities (incl. the ones named by the client) ─────────
  ('Bowen University, Iwo', 'uni_bowen', 'university', TRUE, 'active'),
  ('Bowen University Teaching Hospital', 'uni_bowenoth', 'university', TRUE, 'active'),
  ('Nigeria Baptist Theological Seminary, Ogbomoso', 'uni_nbts', 'university', TRUE, 'active'),
  ('Covenant University', 'uni_covenant', 'university', TRUE, 'active'),
  ('Babcock University', 'uni_babcock', 'university', TRUE, 'active'),
  ('Lagos Business School', 'uni_lbs', 'university', TRUE, 'active'),
  ('American University of Nigeria', 'uni_aun', 'university', TRUE, 'active'),
  ('Afe Babalola University', 'uni_abuad', 'university', TRUE, 'active'),
  ('Bells University of Technology', 'uni_bells', 'university', TRUE, 'active'),
  ('Redeemer''s University', 'uni_run', 'university', TRUE, 'active'),
  ('Ajayi Crowther University', 'uni_acu', 'university', TRUE, 'active'),
  ('Lead City University', 'uni_lcu', 'university', TRUE, 'active'),
  ('Igbinedion University', 'uni_iuokada', 'university', TRUE, 'active'),
  ('Madonna University', 'uni_madonna', 'university', TRUE, 'active'),
  ('Nigerian Turkish Nile University', 'uni_ntnu', 'university', TRUE, 'active'),
  ('Baze University', 'uni_baze', 'university', TRUE, 'active'),
  ('Elizade University', 'uni_elizade', 'university', TRUE, 'active'),
  ('Adeleke University', 'uni_adeleke', 'university', TRUE, 'active'),
  ('Joseph Ayo Babalola University', 'uni_jabu', 'university', TRUE, 'active'),
  ('Salem University', 'uni_salem', 'university', TRUE, 'active'),
  ('Landmark University', 'uni_landmark', 'university', TRUE, 'active'),
  ('Pan-Atlantic University', 'uni_pau', 'university', TRUE, 'active'),
  ('Augustine University', 'uni_augustine', 'university', TRUE, 'active'),
  ('Chrisland University', 'uni_chrisland', 'university', TRUE, 'active'),
  ('Mountain Top University', 'uni_mtu', 'university', TRUE, 'active'),
  ('Anchor University', 'uni_anchor', 'university', TRUE, 'active'),
  ('Trinity University', 'uni_trinity', 'university', TRUE, 'active'),
  ('Hallmark University', 'uni_hallmark', 'university', TRUE, 'active'),
  ('Rhema University', 'uni_rhema', 'university', TRUE, 'active'),
  ('Wellspring University', 'uni_wellspring', 'university', TRUE, 'active'),

  -- ── Banks ─────────────────────────────────────────────────────────────
  ('Access Bank', 'bank_access', 'bank', TRUE, 'active'),
  ('Citibank Nigeria', 'bank_citibank', 'bank', TRUE, 'active'),
  ('Ecobank Nigeria', 'bank_ecobank', 'bank', TRUE, 'active'),
  ('Fidelity Bank', 'bank_fidelity', 'bank', TRUE, 'active'),
  ('First Bank of Nigeria', 'bank_firstbank', 'bank', TRUE, 'active'),
  ('First City Monument Bank (FCMB)', 'bank_fcmb', 'bank', TRUE, 'active'),
  ('Guaranty Trust Bank (GTBank)', 'bank_gtbank', 'bank', TRUE, 'active'),
  ('Heritage Bank', 'bank_heritage', 'bank', TRUE, 'active'),
  ('Keystone Bank', 'bank_keystone', 'bank', TRUE, 'active'),
  ('Polaris Bank', 'bank_polaris', 'bank', TRUE, 'active'),
  ('Providus Bank', 'bank_providus', 'bank', TRUE, 'active'),
  ('Stanbic IBTC Bank', 'bank_stanbic', 'bank', TRUE, 'active'),
  ('Standard Chartered Bank Nigeria', 'bank_stanchart', 'bank', TRUE, 'active'),
  ('Sterling Bank', 'bank_sterling', 'bank', TRUE, 'active'),
  ('SunTrust Bank Nigeria', 'bank_suntrust', 'bank', TRUE, 'active'),
  ('Union Bank of Nigeria', 'bank_union', 'bank', TRUE, 'active'),
  ('United Bank for Africa (UBA)', 'bank_uba', 'bank', TRUE, 'active'),
  ('Unity Bank', 'bank_unity', 'bank', TRUE, 'active'),
  ('Wema Bank', 'bank_wema', 'bank', TRUE, 'active'),
  ('Zenith Bank', 'bank_zenith', 'bank', TRUE, 'active'),
  ('Jaiz Bank', 'bank_jaiz', 'bank', TRUE, 'active'),
  ('Lotus Bank', 'bank_lotus', 'bank', TRUE, 'active'),
  ('Optimism Bank', 'bank_optimism', 'bank', TRUE, 'active'),
  ('Parallex Bank', 'bank_parallex', 'bank', TRUE, 'active'),
  ('Premium Trust Bank', 'bank_premiumtrust', 'bank', TRUE, 'active'),
  ('Signature Bank', 'bank_signature', 'bank', TRUE, 'active'),
  ('Taj Bank', 'bank_taj', 'bank', TRUE, 'active'),

  -- ── Private companies (major employers) ───────────────────────────────
  ('Dangote Group', 'corp_dangote', 'company', TRUE, 'active'),
  ('MTN Nigeria', 'corp_mtn', 'company', TRUE, 'active'),
  ('Airtel Nigeria', 'corp_airtel', 'company', TRUE, 'active'),
  ('Globacom', 'corp_glo', 'company', TRUE, 'active'),
  ('9mobile', 'corp_9mobile', 'company', TRUE, 'active'),
  ('Nestlé Nigeria', 'corp_nestle', 'company', TRUE, 'active'),
  ('Unilever Nigeria', 'corp_unilever', 'company', TRUE, 'active'),
  ('Nigerian Breweries', 'corp_nb', 'company', TRUE, 'active'),
  ('Guinness Nigeria', 'corp_guinness', 'company', TRUE, 'active'),
  ('Flour Mills of Nigeria', 'corp_flourmills', 'company', TRUE, 'active'),
  ('Nigerian Bottling Company', 'corp_nbc', 'company', TRUE, 'active'),
  ('Coca-Cola Hellenic Bottling Company', 'corp_cchbc', 'company', TRUE, 'active'),
  ('PZ Cussons Nigeria', 'corp_pz', 'company', TRUE, 'active'),
  ('Cadbury Nigeria', 'corp_cadbury', 'company', TRUE, 'active'),
  ('Honeywell Group', 'corp_honeywell', 'company', TRUE, 'active'),
  ('Julius Berger Nigeria', 'corp_juliusberger', 'company', TRUE, 'active'),
  ('Total Energies Nigeria', 'corp_total', 'company', TRUE, 'active'),
  ('Shell Nigeria', 'corp_shell', 'company', TRUE, 'active'),
  ('Chevron Nigeria', 'corp_chevron', 'company', TRUE, 'active'),
  ('ExxonMobil Nigeria', 'corp_exxonmobil', 'company', TRUE, 'active'),
  ('NNPC Limited', 'corp_nnpc', 'company', TRUE, 'active'),
  ('First Exploration and Petroleum Development Company', 'corp_firstepd', 'company', TRUE, 'active'),
  ('Seplat Energy', 'corp_seplat', 'company', TRUE, 'active'),
  ('Oando Plc', 'corp_oando', 'company', TRUE, 'active'),
  ('Nigerian National Petroleum Development Company', 'corp_nnpdc', 'company', TRUE, 'active'),
  ('Deloitte Nigeria', 'corp_deloitte', 'company', TRUE, 'active'),
  ('KPMG Nigeria', 'corp_kpmg', 'company', TRUE, 'active'),
  ('PricewaterhouseCoopers (PwC) Nigeria', 'corp_pwc', 'company', TRUE, 'active'),
  ('Ernst & Young (EY) Nigeria', 'corp_ey', 'company', TRUE, 'active'),
  ('Accenture Nigeria', 'corp_accenture', 'company', TRUE, 'active'),
  ('Andela', 'corp_andela', 'company', TRUE, 'active'),
  ('Flutterwave', 'corp_flutterwave', 'company', TRUE, 'active'),
  ('Paystack', 'corp_paystack', 'company', TRUE, 'active'),
  ('OPay', 'corp_opay', 'company', TRUE, 'active'),
  ('PalmPay', 'corp_palmpay', 'company', TRUE, 'active'),
  ('Kuda Bank', 'corp_kuda', 'company', TRUE, 'active'),
  ('Moniepoint', 'corp_moniepoint', 'company', TRUE, 'active'),
  ('IHS Towers Nigeria', 'corp_ihs', 'company', TRUE, 'active'),
  ('Shoprite Nigeria', 'corp_shoprite', 'company', TRUE, 'active'),
  ('Jumia Nigeria', 'corp_jumia', 'company', TRUE, 'active'),
  ('Konga', 'corp_konga', 'company', TRUE, 'active'),
  ('Interswitch', 'corp_interswitch', 'company', TRUE, 'active'),
  ('SystemSpecs', 'corp_systemspecs', 'company', TRUE, 'active'),
  ('Hyundai Motors Nigeria', 'corp_hyundai', 'company', TRUE, 'active'),
  ('Toyota Nigeria (CFAO)', 'corp_toyota', 'company', TRUE, 'active'),
  ('Elizade Nigeria', 'corp_elizade', 'company', TRUE, 'active'),
  ('Mikano International', 'corp_mikano', 'company', TRUE, 'active'),
  ('BUA Group', 'corp_bua', 'company', TRUE, 'active'),
  ('Lafarge Africa', 'corp_lafarge', 'company', TRUE, 'active'),
  ('Berger Paints Nigeria', 'corp_berger', 'company', TRUE, 'active'),
  ('Chi Limited', 'corp_chi', 'company', TRUE, 'active'),
  ('FrieslandCampina WAMCO', 'corp_friesland', 'company', TRUE, 'active'),
  ('Grand Cereals', 'corp_grandcereals', 'company', TRUE, 'active'),
  ('Fan Milk Nigeria', 'corp_fanmilk', 'company', TRUE, 'active'),
  ('UAC of Nigeria', 'corp_uac', 'company', TRUE, 'active'),
  ('May & Baker Nigeria', 'corp_maybaker', 'company', TRUE, 'active'),
  ('Emzor Pharmaceutical', 'corp_emzor', 'company', TRUE, 'active'),
  ('Fidson Healthcare', 'corp_fidson', 'company', TRUE, 'active'),
  ('GlaxoSmithKline Nigeria', 'corp_gsk', 'company', TRUE, 'active'),
  ('FBN Holdings', 'corp_fbnholdings', 'company', TRUE, 'active'),
  ('Africa Prudential', 'corp_africaprudential', 'company', TRUE, 'active'),
  ('Nigerian Exchange Group', 'corp_nxgroup', 'company', TRUE, 'active'),
  ('Central Securities Clearing System', 'corp_cscs', 'company', TRUE, 'active'),
  ('Leadway Assurance', 'corp_leadway', 'company', TRUE, 'active'),
  ('AXA Mansard', 'corp_axamansard', 'company', TRUE, 'active'),
  ('AIICO Insurance', 'corp_aiico', 'company', TRUE, 'active'),
  ('Mutual Benefits Assurance', 'corp_mutualbenefits', 'company', TRUE, 'active'),
  ('NEM Insurance', 'corp_nem', 'company', TRUE, 'active'),
  ('Custodian Investment', 'corp_custodian', 'company', TRUE, 'active'),
  ('Wapic Insurance', 'corp_wapic', 'company', TRUE, 'active'),
  ('Cornerstone Insurance', 'corp_cornerstone', 'company', TRUE, 'active'),
  ('Sovereign Trust Insurance', 'corp_sovereigntrust', 'company', TRUE, 'active'),
  ('Prestige Assurance', 'corp_prestige', 'company', TRUE, 'active'),
  ('Consolidated Hallmark Insurance', 'corp_consolidatedhallmark', 'company', TRUE, 'active'),
  ('LASACO Assurance', 'corp_lasaco', 'company', TRUE, 'active'),
  ('Regency Alliance Insurance', 'corp_regency', 'company', TRUE, 'active'),
  ('Veritas Kapital Assurance', 'corp_veritas', 'company', TRUE, 'active'),
  ('SUNU Assurances Nigeria', 'corp_sunu', 'company', TRUE, 'active'),
  ('Linkage Assurance', 'corp_linkage', 'company', TRUE, 'active'),
  ('Universal Insurance', 'corp_universalinsurance', 'company', TRUE, 'active'),
  ('Continental Reinsurance', 'corp_continentalre', 'company', TRUE, 'active'),
  ('Africa Reinsurance Corporation', 'corp_africare', 'company', TRUE, 'active'),

  -- ── Government / public sector ────────────────────────────────────────
  ('Federal Ministry of Finance', 'gov_fmf', 'government', TRUE, 'active'),
  ('Federal Ministry of Education', 'gov_fme', 'government', TRUE, 'active'),
  ('Federal Ministry of Health', 'gov_fmh', 'government', TRUE, 'active'),
  ('Federal Inland Revenue Service (FIRS)', 'gov_firs', 'government', TRUE, 'active'),
  ('Nigeria Customs Service', 'gov_customs', 'government', TRUE, 'active'),
  ('National Identity Management Commission (NIMC)', 'gov_nimc', 'government', TRUE, 'active'),
  ('National Pension Commission (PenCom)', 'gov_pencom', 'government', TRUE, 'active'),
  ('Joint Admissions and Matriculation Board (JAMB)', 'gov_jamb', 'government', TRUE, 'active'),
  ('National Youth Service Corps (NYSC)', 'gov_nysc', 'government', TRUE, 'active'),
  ('Nigerian Communications Commission (NCC)', 'gov_ncc', 'government', TRUE, 'active'),
  ('Nigerian National Petroleum Corporation Limited', 'gov_nnpcl', 'government', TRUE, 'active'),
  ('Central Bank of Nigeria', 'gov_cbn', 'government', TRUE, 'active'),
  ('Nigerian Ports Authority', 'gov_npa', 'government', TRUE, 'active'),
  ('Federal Road Safety Corps (FRSC)', 'gov_frsc', 'government', TRUE, 'active'),
  ('Nigerian Immigration Service', 'gov_nis', 'government', TRUE, 'active'),
  ('Nigeria Police Force', 'gov_npf', 'government', TRUE, 'active'),
  ('Nigerian Army', 'gov_army', 'government', TRUE, 'active'),
  ('Nigerian Navy', 'gov_navy', 'government', TRUE, 'active'),
  ('Nigerian Air Force', 'gov_airforce', 'government', TRUE, 'active'),
  ('Nigerian Correctional Service', 'gov_ncs', 'government', TRUE, 'active')
ON CONFLICT (code) DO NOTHING;

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