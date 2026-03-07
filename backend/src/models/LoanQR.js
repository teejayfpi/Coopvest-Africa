/**
 * LoanQR Model
 * 
 * Model for tracking loan guarantor QR codes
 * Stores QR code metadata, scanning statistics, and audit trail
 */

const { v4: uuidv4 } = require('uuid');

/**
 * LoanQR class for managing loan QR code records
 */
class LoanQR {
  constructor(data = {}) {
    this.qrId = data.qrId || `QR_${Date.now()}_${uuidv4().substring(0, 8)}`;
    this.loanId = data.loanId;
    this.applicantId = data.applicantId;
    this.applicantName = data.applicantName;
    this.applicantPhone = data.applicantPhone;
    this.loanAmount = data.loanAmount;
    this.loanCurrency = data.loanCurrency || 'NGN';
    this.loanTenure = data.loanTenure;
    this.interestRate = data.interestRate;
    this.monthlyRepayment = data.monthlyRepayment;
    this.totalRepayment = data.totalRepayment;
    this.purpose = data.purpose;
    this.qrData = data.qrData; // Full QR data with signature
    this.qrCode = data.qrCode; // Base64 encoded QR image
    this.signature = data.signature;
    this.createdAt = data.createdAt || new Date();
    this.expiresAt = data.expiresAt || new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    this.status = data.status || 'active'; // active, expired, invalidated
    this.scanCount = data.scanCount || 0;
    this.guarantorsFound = data.guarantorsFound || 0;
    this.guarantorsRequired = data.guarantorsRequired || 3;
    this.scans = data.scans || []; // Array of scan events
    this.createdBy = data.createdBy;
    this.notes = data.notes;
  }

  /**
   * Convert to JSON for API responses (without sensitive data)
   */
  toJSON(includeSensitive = false) {
    const json = {
      qrId: this.qrId,
      loanId: this.loanId,
      applicantName: this.applicantName,
      applicantPhone: this.applicantPhone,
      loanAmount: this.loanAmount,
      loanCurrency: this.loanCurrency,
      loanTenure: this.loanTenure,
      interestRate: this.interestRate,
      monthlyRepayment: this.monthlyRepayment,
      totalRepayment: this.totalRepayment,
      purpose: this.purpose,
      status: this.status,
      scanCount: this.scanCount,
      guarantorsFound: this.guarantorsFound,
      guarantorsRequired: this.guarantorsRequired,
      expiresAt: this.expiresAt,
      createdAt: this.createdAt,
      isExpired: this.isExpired(),
      progress: this.getProgress()
    };

    if (includeSensitive) {
      json.qrCode = this.qrCode;
      json.qrData = this.qrData;
    }

    return json;
  }

  /**
   * Convert to database storage format
   */
  toStorage() {
    return {
      qr_id: this.qrId,
      loan_id: this.loanId,
      applicant_id: this.applicantId,
      applicant_name: this.applicantName,
      applicant_phone: this.applicantPhone,
      loan_amount: this.loanAmount,
      loan_currency: this.loanCurrency,
      loan_tenure: this.loanTenure,
      interest_rate: this.interestRate,
      monthly_repayment: this.monthlyRepayment,
      total_repayment: this.totalRepayment,
      purpose: this.purpose,
      qr_data: JSON.stringify(this.qrData),
      qr_code: this.qrCode,
      signature: this.signature,
      created_at: this.createdAt.toISOString(),
      expires_at: this.expiresAt.toISOString(),
      status: this.status,
      scan_count: this.scanCount,
      guarantors_found: this.guarantorsFound,
      guarantors_required: this.guarantorsRequired,
      scans: JSON.stringify(this.scans),
      created_by: this.createdBy,
      notes: this.notes
    };
  }

  /**
   * Create from database storage format
   */
  static fromStorage(storage) {
    return new LoanQR({
      qrId: storage.qr_id,
      loanId: storage.loan_id,
      applicantId: storage.applicant_id,
      applicantName: storage.applicant_name,
      applicantPhone: storage.applicant_phone,
      loanAmount: storage.loan_amount,
      loanCurrency: storage.loan_currency,
      loanTenure: storage.loan_tenure,
      interestRate: storage.interest_rate,
      monthlyRepayment: storage.monthly_repayment,
      totalRepayment: storage.total_repayment,
      purpose: storage.purpose,
      qrData: storage.qr_data ? JSON.parse(storage.qr_data) : null,
      qrCode: storage.qr_code,
      signature: storage.signature,
      createdAt: new Date(storage.created_at),
      expiresAt: new Date(storage.expires_at),
      status: storage.status,
      scanCount: storage.scan_count,
      guarantorsFound: storage.guarantors_found,
      guarantorsRequired: storage.guarantors_required,
      scans: storage.scans ? JSON.parse(storage.scans) : [],
      createdBy: storage.created_by,
      notes: storage.notes
    });
  }

  /**
   * Check if QR code is expired
   */
  isExpired() {
    return new Date() > this.expiresAt;
  }

  /**
   * Get guarantor progress percentage
   */
  getProgress() {
    return {
      found: this.guarantorsFound,
      required: this.guarantorsRequired,
      percentage: Math.round((this.guarantorsFound / this.guarantorsRequired) * 100),
      remaining: this.guarantorsRequired - this.guarantorsFound
    };
  }

  /**
   * Record a QR scan event
   */
  recordScan(scanData) {
    const scan = {
      scanId: uuidv4(),
      scannedAt: new Date().toISOString(),
      scannerId: scanData.scannerId,
      scannerName: scanData.scannerName,
      action: scanData.action || 'viewed', // viewed, approved, declined
      deviceId: scanData.deviceId,
      ipAddress: scanData.ipAddress,
      location: scanData.location,
      userAgent: scanData.userAgent
    };

    this.scans.push(scan);
    this.scanCount++;

    return scan;
  }

  /**
   * Update guarantor count
   */
  updateGuarantorCount(count) {
    this.guarantorsFound = count;
  }

  /**
   * Invalidate the QR code
   */
  invalidate(reason = 'manual') {
    this.status = 'invalidated';
    this.notes = `Invalidated: ${reason} at ${new Date().toISOString()}`;
  }

  /**
   * Get audit trail
   */
  getAuditTrail() {
    return this.scans.map(scan => ({
      action: scan.action,
      user: scan.scannerName,
      timestamp: scan.scannedAt,
      device: scan.deviceId,
      location: scan.location
    }));
  }
}

module.exports = LoanQR;
