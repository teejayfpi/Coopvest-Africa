/**
 * Registration data merge helpers.
 *
 * The mobile app's complete-registration step may re-submit an earlier-saved
 * payload that omits fields the member already completed. To avoid falsely
 * reporting persisted data as missing, validation merges the request body
 * over the existing KYC row: body fields win when they carry a value,
 * previously saved values fill the gaps.
 */

function hasValue(v) {
  return v !== null && v !== undefined && String(v).trim() !== '';
}

function pickPresent(obj) {
  return Object.fromEntries(Object.entries(obj).filter(([, v]) => hasValue(v)));
}

/**
 * Build the candidate objects used for completeness validation by merging
 * request body fields over the existing KYC row.
 */
function buildRegistrationCandidates(body, existingKyc) {
  const personalBody = {
    gender: body.gender,
    address: body.address,
    state: body.state,
    lga: body.lga,
    staff_id: body.staff_id,
    id_type: body.id_type,
    nok_name: body.nok_name,
    nok_relationship: body.nok_relationship,
    nok_phone: body.nok_phone,
    nok_address: body.nok_address,
    monthly_amount: body.monthly_amount,
    contribution_method: body.contribution_method,
    preferred_payment_day: body.preferred_payment_day,
  };
  const employmentBody = {
    occupation: body.occupation,
    employer_name: body.employer_name,
    employment_type: body.employment_type,
    employer_staff_id: body.employer_staff_id,
    work_address: body.work_address,
    years_of_employment: body.years_of_employment,
  };

  const personal_info = {
    ...(existingKyc?.personal_info || {}),
    ...pickPresent(personalBody),
    // date_of_birth is both a top-level kyc column and (historically) inside
    // personal_info; accept either persisted location when the body omits it.
    date_of_birth: hasValue(body.date_of_birth)
      ? body.date_of_birth
      : (existingKyc?.date_of_birth || existingKyc?.personal_info?.date_of_birth),
  };

  const employment_info = {
    ...(existingKyc?.employment_info || {}),
    ...pickPresent(employmentBody),
  };

  return { personal_info, employment_info };
}

/**
 * Merge a stored personal_info object with the top-level date_of_birth
 * column, for the status/completeness read endpoints.
 */
function mergeStoredPersonalInfo(kycRow) {
  if (!kycRow) return {};
  return {
    ...(kycRow.personal_info || {}),
    date_of_birth: kycRow.personal_info?.date_of_birth || kycRow.date_of_birth,
  };
}

module.exports = { hasValue, buildRegistrationCandidates, mergeStoredPersonalInfo };
