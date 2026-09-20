-- 043_expand_tertiary_organizations.sql
--
-- Completes the tertiary-institution list and adds every polytechnic.
--
-- WHY
-- ---
-- 042 seeded a starter set (202 employers). Review feedback: the university
-- list was incomplete, every polytechnic was missing, and The Federal
-- University of Agriculture and Technology, Okeho was absent. Members cannot
-- pick an employer that is not listed — the only fallback is the
-- "Request my employer" flow, which puts them in a queue instead of letting
-- them finish KYC.
--
-- SCOPE
-- The full federal university system, the state universities, the private
-- universities, and the federal/state/private polytechnics and colleges of
-- technology. Codes are prefixed so the type is obvious at a glance:
--   uni_*    university
--   poly_*   polytechnic / college of technology
--
-- As in 042, remittance bank details are deliberately NOT set: they are
-- per-employer commercial data and a placeholder account could misroute money.
-- `deduction_enabled = TRUE` here means "selectable by members", NOT "ready to
-- remit". Finance must set remittance details (or disable) before payroll runs.
--
-- DUPLICATES
-- Names were checked against what 042 already seeded. 25 entries were dropped
-- because they were the same institution under a different label — either an
-- exact repeat (e.g. "Bowen University, Iwo") or the same university with its
-- campus town appended (e.g. "Covenant University, Ota" when "Covenant
-- University" is already listed). Listing both would have shown members the
-- same employer twice and let them pick the wrong row. Genuinely distinct
-- institutions that share a name prefix are kept, e.g. every
-- "Federal Polytechnic, <town>" — the town is the identifier there, not a
-- campus of one polytechnic.
--
-- Idempotent: `code` carries a PARTIAL unique index
-- (idx_organizations_code ... WHERE code IS NOT NULL), which `ON CONFLICT
-- (code)` cannot infer, so the insert is guarded with NOT EXISTS on the code.
-- Re-running is a no-op and never clobbers an admin's edits.

INSERT INTO public.organizations (name, code, type, deduction_enabled, status, is_active)
SELECT v.name, v.code, v.type, TRUE, 'active', TRUE
FROM (VALUES
  -- ── Federal universities ──────────────────────────────────────────────
  ('Federal University of Agriculture and Technology, Okeho', 'uni_fuato', 'university'),
  ('Abubakar Tafawa Balewa University', 'uni_atbu', 'university'),
  ('Alex Ekwueme Federal University, Ndufu-Alike', 'uni_aefunai', 'university'),
  ('Federal University, Birnin Kebbi', 'uni_fubk', 'university'),
  ('Federal University, Dutse', 'uni_fud', 'university'),
  ('Federal University, Dutsin-Ma', 'uni_fudma', 'university'),
  ('Federal University, Gashua', 'uni_fugashua', 'university'),
  ('Federal University, Gusau', 'uni_fugusau', 'university'),
  ('Federal University, Kashere', 'uni_fukashere', 'university'),
  ('Federal University, Lafia', 'uni_fulafia', 'university'),
  ('Federal University, Lokoja', 'uni_fulokoja', 'university'),
  ('Federal University, Wukari', 'uni_fuwukari', 'university'),
  ('Federal University of Health Sciences, Azare', 'uni_fuhsa', 'university'),
  ('Federal University of Health Sciences, Ila Orangun', 'uni_fuhsi', 'university'),
  ('Federal University of Health Sciences, Otukpo', 'uni_fuhso', 'university'),
  ('Federal University of Petroleum Resources, Effurun', 'uni_fupre', 'university'),
  ('Federal University of Technology, Babura', 'uni_futb', 'university'),
  ('Federal University of Technology, Ikot Abasi', 'uni_futia', 'university'),
  ('Federal University, Otuoke', 'uni_fuotuoke', 'university'),
  ('National Open University of Nigeria', 'uni_noun', 'university'),
  ('Nigerian Maritime University, Okerenkoko', 'uni_nmu', 'university'),
  ('Nigerian University of Technology and Management, Apapa', 'uni_nutmapapa', 'university'),
  ('Nigerian Defence Academy', 'uni_nda', 'university'),
  ('Police Academy Wudil', 'uni_polacwudil', 'university'),
  ('Air Force Institute of Technology', 'uni_afit', 'university'),
  ('National Mathematical Centre', 'uni_nmc', 'university'),
  ('University of Agriculture and Environmental Sciences, Umuagwo', 'uni_uaesu', 'university'),
  ('Federal University of Transportation, Daura', 'uni_futdaura', 'university'),
  ('Federal University of Education, Kano', 'uni_fuekano', 'university'),
  ('Federal University of Education, Zaria', 'uni_fuezaria', 'university'),
  ('Federal University of Education, Kontagora', 'uni_fuekonta', 'university'),
  ('Federal University of Education, Pankshin', 'uni_fuepankshin', 'university'),
  ('Michael Okpara Federal University of Agriculture, Umudike', 'uni_mouau2', 'university'),
  ('Federal University of Agriculture, Zuru', 'uni_fuazuru', 'university'),
  ('Federal University of Health Sciences, Kwale', 'uni_fuhskwale', 'university'),
  ('Federal University of Allied Health Sciences, Enugu', 'uni_fuahse', 'university'),
  ('Federal University of Medical Sciences, Katsina', 'uni_fumskatsina', 'university'),
  ('Federal University of Environment and Technology, Ogoni', 'uni_fuetogoni', 'university'),
  ('Federal University of Applied Sciences, Kachia', 'uni_fuaskachia', 'university'),
  ('Federal University of Agriculture, Mubi', 'uni_fuamubi', 'university'),
  ('Federal University, Grie', 'uni_fugrie', 'university'),
  ('Federal University of Science and Technology, Kachia', 'uni_fustkachia', 'university'),

  -- ── State universities (remaining) ────────────────────────────────────
  ('Chukwuemeka Odumegwu Ojukwu University', 'uni_coou', 'university'),
  ('Godfrey Okoye University', 'uni_gouni', 'university'),
  ('Ignatius Ajuru University of Education', 'uni_iaue', 'university'),
  ('Nnamdi Azikiwe University Awka', 'uni_unizik2', 'university'),
  ('Kebbi State University of Science and Technology', 'uni_ksust', 'university'),
  ('Katsina State University', 'uni_uamkatsina', 'university'),
  ('Zamfara State University', 'uni_zsu', 'university'),
  ('Gombe State University', 'uni_gsu', 'university'),
  ('Adamawa State University', 'uni_adsu', 'university'),
  ('Taraba State University', 'uni_tsu', 'university'),
  ('Yobe State University', 'uni_ysu', 'university'),
  ('Bauchi State University, Gadau', 'uni_basug', 'university'),
  ('Sokoto State University', 'uni_ssu', 'university'),
  ('Bayelsa Medical University', 'uni_bmu', 'university'),
  ('University of Africa, Toru-Orua', 'uni_uat', 'university'),
  ('Delta University, Abraka', 'uni_duabraka', 'university'),
  ('Edo University, Iyamho', 'uni_eui', 'university'),
  ('Edo State University, Uzairue', 'uni_esuu', 'university'),
  ('Confluence University of Science and Technology', 'uni_custech', 'university'),
  ('Prince Abubakar Audu University', 'uni_paau', 'university'),
  ('Bamidele Olumilua University of Education', 'uni_bouesti', 'university'),
  ('University of Medical Sciences, Ondo', 'uni_unimed', 'university'),
  ('Ondo State University of Medical Sciences', 'uni_unimed2', 'university'),
  ('Achievers University', 'uni_achievers', 'university'),
  ('Federal Polytechnic, Ilaro', 'poly_ilaro', 'polytechnic'),
  ('Kwara State University', 'uni_kwasu', 'university'),
  ('University of Ilesa', 'uni_unilesa', 'university'),
  ('Lagos State University of Science and Technology', 'uni_lasustech', 'university'),
  ('Lagos State University of Education', 'uni_lasued', 'university'),
  ('Yaba College of Technology', 'poly_yabatech', 'polytechnic'),
  ('Tai Solarin Federal University of Education', 'uni_tsfue', 'university'),
  ('Federal College of Education, Abeokuta', 'poly_fceabeokuta', 'polytechnic'),
  ('Federal University of Education, Oyo', 'uni_fueoyo', 'university'),
  ('The Technical University, Ibadan', 'uni_techibadan', 'university'),
  ('First Technical University', 'uni_firsttech', 'university'),
  ('Nigerian Army University, Biu', 'uni_naub', 'university'),
  ('Veritas University', 'uni_veritas', 'university'),
  ('Nile University of Nigeria', 'uni_nile', 'university'),
  ('African University of Science and Technology', 'uni_aust', 'university'),
  ('Bingham University', 'uni_bingham', 'university'),
  ('Federal University of Lafia', 'uni_fulafia2', 'university'),

  -- ── Private universities (remaining) ──────────────────────────────────
  ('Al-Hikmah University', 'uni_alhikmah', 'university'),
  ('Kola Daisi University', 'uni_kdu', 'university'),
  ('Dominion University', 'uni_dominion', 'university'),
  ('Precious Cornerstone University', 'uni_pcu', 'university'),
  ('Crawford University', 'uni_crawford', 'university'),
  ('Caleb University', 'uni_caleb', 'university'),
  ('Anchor University Lagos', 'uni_anchor2', 'university'),
  ('Christopher University', 'uni_christopher', 'university'),
  ('Hallmark University Ijebu-Itele', 'uni_hallmark2', 'university'),
  ('McPherson University', 'uni_mcpherson', 'university'),
  ('Southwestern University Nigeria', 'uni_southwestern', 'university'),
  ('Samuel Adegboyega University', 'uni_sau', 'university'),
  ('Wesley University of Science and Technology', 'uni_wesley', 'university'),
  ('Western Delta University', 'uni_wdu', 'university'),
  ('Novena University', 'uni_novena', 'university'),
  ('Renaissance University', 'uni_renaissance', 'university'),
  ('Evangel University', 'uni_evangel', 'university'),
  ('Coal City University', 'uni_ccu', 'university'),
  ('Madonna University Nigeria', 'uni_madonna2', 'university'),
  ('Legacy University', 'uni_legacy', 'university'),
  ('Paul University', 'uni_paul', 'university'),
  ('Tansian University', 'uni_tansian', 'university'),
  ('Caritas University', 'uni_caritas', 'university'),
  ('Gregory University', 'uni_gregory', 'university'),
  ('Rhema University Nigeria', 'uni_rhema2', 'university'),
  ('Spiritan University', 'uni_spiritan', 'university'),
  ('Clifford University', 'uni_clifford', 'university'),
  ('Arthur Jarvis University', 'uni_arthurjarvis', 'university'),
  ('University of Mkar', 'uni_unimkar', 'university'),
  ('Joseph Sarwuan Tarka University', 'uni_jstu', 'university'),
  ('University of Agriculture, Makurdi', 'uni_uam', 'university'),
  ('Fountain University', 'uni_fountain', 'university'),
  ('Oduduwa University', 'uni_oduduwa', 'university'),
  ('Adeleke University Ede', 'uni_adeleke2', 'university'),
  ('Redeemer''s College of Technology and Management', 'uni_rctm', 'university'),
  ('Nigerian Baptist Theological Seminary, Ogbomoso', 'uni_nbts2', 'university'),
  ('Achievers University, Owo', 'uni_achievers2', 'university'),

  -- ── Federal polytechnics ──────────────────────────────────────────────
  ('Federal Polytechnic, Ado-Ekiti', 'poly_fedpolyado', 'polytechnic'),
  ('Federal Polytechnic, Bauchi', 'poly_fedpolybauchi', 'polytechnic'),
  ('Federal Polytechnic, Bida', 'poly_fedpolybida', 'polytechnic'),
  ('Federal Polytechnic, Damaturu', 'poly_fedpolydamaturu', 'polytechnic'),
  ('Federal Polytechnic, Ede', 'poly_fedpolyede', 'polytechnic'),
  ('Federal Polytechnic, Ekowe', 'poly_fedpolyekowe', 'polytechnic'),
  ('Federal Polytechnic, Idah', 'poly_fedpolyidah', 'polytechnic'),
  ('Federal Polytechnic, Ile-Oluji', 'poly_fedpolyileoluji', 'polytechnic'),
  ('Federal Polytechnic, Kaura Namoda', 'poly_fedpolykaura', 'polytechnic'),
  ('Federal Polytechnic, Kazaure', 'poly_fedpolykazaure', 'polytechnic'),
  ('Federal Polytechnic, Mubi', 'poly_fedpolymubi', 'polytechnic'),
  ('Federal Polytechnic, Namoda', 'poly_fedpolynamoda', 'polytechnic'),
  ('Federal Polytechnic, Nasarawa', 'poly_fedpolynasarawa', 'polytechnic'),
  ('Federal Polytechnic, Nekede', 'poly_fedpolynekede', 'polytechnic'),
  ('Federal Polytechnic, Offa', 'poly_fedpolyoffa', 'polytechnic'),
  ('Federal Polytechnic, Oko', 'poly_fedpolyoko', 'polytechnic'),
  ('Federal Polytechnic, Ugep', 'poly_fedpolyugep', 'polytechnic'),
  ('Auchi Polytechnic', 'poly_auchi', 'polytechnic'),
  ('Kaduna Polytechnic', 'poly_kaduna', 'polytechnic'),
  ('The Polytechnic, Ibadan', 'poly_ibadan', 'polytechnic'),
  ('Port Harcourt Polytechnic', 'poly_portharcourt', 'polytechnic'),
  ('Hussaini Adamu Federal Polytechnic', 'poly_hafpoly', 'polytechnic'),
  ('Federal Polytechnic, Bali', 'poly_fedpolybali', 'polytechnic'),
  ('Federal Polytechnic, Wannune', 'poly_fedpolywannune', 'polytechnic'),
  ('Federal Polytechnic, Nyak Shendam', 'poly_fedpolynyak', 'polytechnic'),

  -- ── State polytechnics ────────────────────────────────────────────────
  ('Kwara State Polytechnic', 'poly_kwarastate', 'polytechnic'),
  ('Lagos State Polytechnic', 'poly_laspotech', 'polytechnic'),
  ('Moshood Abiola Polytechnic', 'poly_mapoly', 'polytechnic'),
  ('Osun State Polytechnic, Iree', 'poly_osunpolyiree', 'polytechnic'),
  ('Ondo State Polytechnic', 'poly_ondopoly', 'polytechnic'),
  ('Rufus Giwa Polytechnic', 'poly_rugipo', 'polytechnic'),
  ('Oyo State College of Agriculture and Technology', 'poly_oyscatech', 'polytechnic'),
  ('The Polytechnic, Ile-Ife', 'poly_ileife', 'polytechnic'),
  ('Delta State Polytechnic, Ogwashi-Uku', 'poly_dspogwashi', 'polytechnic'),
  ('Delta State Polytechnic, Otefe-Oghara', 'poly_dspotefe', 'polytechnic'),
  ('Delta State Polytechnic, Ozoro', 'poly_dspozoro', 'polytechnic'),
  ('Edo State Polytechnic, Usen', 'poly_edopoly', 'polytechnic'),
  ('Auchi Polytechnic, Auchi', 'poly_auchi2', 'polytechnic'),
  ('Institute of Management and Technology, Enugu', 'poly_imt', 'polytechnic'),
  ('Federal Polytechnic, Oko, Anambra', 'poly_fedpolyoko2', 'polytechnic'),
  ('Anambra State Polytechnic', 'poly_anspoly', 'polytechnic'),
  ('Imo State Polytechnic', 'poly_imopoly', 'polytechnic'),
  ('Abia State Polytechnic', 'poly_abiapoly', 'polytechnic'),
  ('Rivers State Polytechnic', 'poly_riverspoly', 'polytechnic'),
  ('Captain Elechi Amadi Polytechnic', 'poly_ceapoly', 'polytechnic'),
  ('Kenule Beeson Saro-Wiwa Polytechnic', 'poly_kbsopoly', 'polytechnic'),
  ('Akwa Ibom State Polytechnic', 'poly_akwapoly', 'polytechnic'),
  ('Cross River State Institute of Technology', 'poly_crsit', 'polytechnic'),
  ('Benue State Polytechnic', 'poly_benuepoly', 'polytechnic'),
  ('Plateau State Polytechnic', 'poly_plateaupoly', 'polytechnic'),
  ('Nasarawa State Polytechnic', 'poly_nasarawapoly', 'polytechnic'),
  ('Niger State Polytechnic', 'poly_nigerpoly', 'polytechnic'),
  ('Kogi State Polytechnic', 'poly_kogipoly', 'polytechnic'),
  ('Kano State Polytechnic', 'poly_kanopoly', 'polytechnic'),
  ('Jigawa State Polytechnic', 'poly_jigawapoly', 'polytechnic'),
  ('Katsina State Institute of Technology', 'poly_katsinainst', 'polytechnic'),
  ('Kebbi State Polytechnic', 'poly_kebbipoly', 'polytechnic'),
  ('Sokoto State Polytechnic', 'poly_sokotopoly', 'polytechnic'),
  ('Zamfara State Polytechnic', 'poly_zamfarapoly', 'polytechnic'),
  ('Borno State Polytechnic', 'poly_bornopoly', 'polytechnic'),
  ('Yobe State Polytechnic', 'poly_yobepoly', 'polytechnic'),
  ('Adamawa State Polytechnic', 'poly_adamawapoly', 'polytechnic'),
  ('Taraba State Polytechnic', 'poly_tarabapoly', 'polytechnic'),
  ('Gombe State Polytechnic', 'poly_gombepoly', 'polytechnic'),
  ('Bauchi State Polytechnic', 'poly_bauchipoly', 'polytechnic'),
  ('Federal College of Agriculture, Akure', 'poly_fcaakure', 'polytechnic'),
  ('Federal College of Agriculture, Ibadan', 'poly_fcaibadan', 'polytechnic'),
  ('Federal College of Agriculture, Ishiagu', 'poly_fcaishiagu', 'polytechnic'),
  ('Federal College of Agriculture, Kabba', 'poly_fcakabba', 'polytechnic'),
  ('Federal College of Forestry, Ibadan', 'poly_fcfibadan', 'polytechnic'),
  ('Federal College of Fisheries and Marine Technology', 'poly_fcfmt', 'polytechnic'),
  ('Federal College of Animal Health and Production Technology', 'poly_fcahpt', 'polytechnic'),
  ('Nigerian Institute of Journalism', 'poly_nij', 'polytechnic'),
  ('Nigerian Institute of Leather and Science Technology', 'poly_nilest', 'polytechnic'),
  ('Federal School of Surveying', 'poly_fss', 'polytechnic'),
  ('Federal College of Dental Technology and Therapy', 'poly_fcdtt', 'polytechnic'),
  ('Yaba College of Technology, Lagos', 'poly_yabatech2', 'polytechnic'),

  -- ── Private polytechnics / colleges of technology ─────────────────────
  ('Nigerian Army School of Electrical and Mechanical Engineering', 'poly_naseme', 'polytechnic'),
  ('Lagos City Polytechnic', 'poly_lagoscitypoly', 'polytechnic'),
  ('Grace Polytechnic', 'poly_gracepoly', 'polytechnic'),
  ('Logos Polytechnic', 'poly_logospoly', 'polytechnic'),
  ('Allover Central Polytechnic', 'poly_allover', 'polytechnic'),
  ('Ronik Polytechnic', 'poly_ronik', 'polytechnic'),
  ('Lighthouse Polytechnic', 'poly_lighthousepoly', 'polytechnic'),
  ('Federal Polytechnic, Ugep, Cross River', 'poly_fedpolyugep2', 'polytechnic'),
  ('Heritage Polytechnic', 'poly_heritagepoly', 'polytechnic'),
  ('Akwa Ibom State College of Arts and Science', 'poly_akscas', 'polytechnic'),
  ('Tower Polytechnic', 'poly_towerpoly', 'polytechnic'),
  ('The Polytechnic, Igbo-Owu', 'poly_igboowu', 'polytechnic')
) AS v(name, code, type)
WHERE v.code IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.organizations o WHERE o.code = v.code
  );

-- Report the resulting coverage per type.
DO $$
DECLARE
  v_total INTEGER;
  v_selectable INTEGER;
  v_uni INTEGER;
  v_poly INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_total FROM public.organizations;
  SELECT COUNT(*) INTO v_selectable
  FROM public.organizations WHERE status = 'active' AND deduction_enabled;
  SELECT COUNT(*) INTO v_uni
  FROM public.organizations WHERE type = 'university';
  SELECT COUNT(*) INTO v_poly
  FROM public.organizations WHERE type = 'polytechnic';

  RAISE NOTICE 'organizations: % total, % selectable (% universities, % polytechnics)',
    v_total, v_selectable, v_uni, v_poly;
  RAISE NOTICE 'REMINDER: remittance bank details are NULL for seeded rows. Set them (or set deduction_enabled = FALSE) before real payroll remits.';
END $$;