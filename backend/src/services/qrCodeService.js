/**
 * QR Code Service
 * 
 * Generates QR codes for referral links and loan guarantor requests
 */

const QRCode = require('qrcode');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

class QRCodeService {
  constructor() {
    // Default QR code options
    this.defaultOptions = {
      errorCorrectionLevel: 'M',
      type: 'image/png',
      quality: 0.92,
      margin: 2,
      color: {
        dark: '#1B5E20',    // Dark green
        light: '#FFFFFF'    // White background
      },
      width: 300
    };

    // Size presets
    this.sizePresets = {
      small: 150,
      medium: 300,
      large: 500,
      xlarge: 800
    };

    // QR code expiry (7 days in milliseconds)
    this.loanQRExpiryMs = 7 * 24 * 60 * 60 * 1000;
    
    // HMAC secret for signing (should be in environment variables)
    this.hmacSecret = process.env.QR_SIGNING_SECRET || 'coopvest-qr-secret-key-2025';
  }

  /**
   * Generate HMAC signature for QR data
   */
  _generateSignature(data) {
    const dataString = JSON.stringify(data);
    return crypto
      .createHmac('sha256', this.hmacSecret)
      .update(dataString)
      .digest('hex');
  }

  /**
   * Verify HMAC signature
   */
  _verifySignature(data, signature) {
    const expectedSignature = this._generateSignature(data);
    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature)
    );
  }

  /**
   * Generate QR code as base64 data URL
   */
  async generateDataURL(data, options = {}) {
    try {
      const mergedOptions = { ...this.defaultOptions, ...options };
      const qrDataURL = await QRCode.toDataURL(data, mergedOptions);
      
      return {
        success: true,
        data: qrDataURL,
        format: 'png',
        size: mergedOptions.width
      };
    } catch (error) {
      throw new Error(`Failed to generate QR code: ${error.message}`);
    }
  }

  /**
   * Generate QR code as Buffer (PNG)
   */
  async generateBuffer(data, options = {}) {
    try {
      const mergedOptions = { ...this.defaultOptions, ...options };
      const buffer = await QRCode.toBuffer(data, mergedOptions);
      
      return {
        success: true,
        buffer,
        format: 'png',
        size: mergedOptions.width
      };
    } catch (error) {
      throw new Error(`Failed to generate QR code: ${error.message}`);
    }
  }

  /**
   * Generate QR code as SVG string
   */
  async generateSVG(data, options = {}) {
    try {
      const svgOptions = {
        type: 'svg',
        errorCorrectionLevel: 'M',
        margin: 2,
        width: options.width || 300,
        color: {
          dark: '#1B5E20',
          light: '#FFFFFF'
        },
        ...options
      };
      
      const svg = await QRCode.toString(data, svgOptions);
      
      return {
        success: true,
        svg,
        format: 'svg'
      };
    } catch (error) {
      throw new Error(`Failed to generate QR code: ${error.message}`);
    }
  }

  /**
   * Generate referral QR code with full configuration
   */
  async generateReferralQR(referralCode, options = {}) {
    try {
      // Build the registration URL
      const baseUrl = process.env.API_BASE_URL || 'https://coopvest.app';
      const registrationUrl = `${baseUrl}/register?ref=${referralCode}&source=qr`;

      // Custom options for referral QR
      const qrOptions = {
        width: options.size || this.sizePresets.medium,
        errorCorrectionLevel: options.errorCorrection || 'H', // Higher error correction
        color: options.color || {
          dark: '#1B5E20',  // Coopvest green
          light: '#FFFFFF'
        },
        margin: options.margin || 2
      };

      // Generate QR code
      const result = await this.generateDataURL(registrationUrl, qrOptions);

      return {
        success: true,
        referralCode,
        registrationUrl,
        qrCode: result.data,
        format: 'png',
        size: qrOptions.width
      };
    } catch (error) {
      throw new Error(`Failed to generate referral QR: ${error.message}`);
    }
  }

  /**
   * Generate multiple QR codes for batch operations
   */
  async generateBatchReferralQRCodes(referralCodes, options = {}) {
    try {
      const results = await Promise.all(
        referralCodes.map(code => this.generateReferralQR(code, options))
      );

      return {
        success: true,
        totalGenerated: results.length,
        qrCodes: results
      };
    } catch (error) {
      throw new Error(`Failed to generate batch QR codes: ${error.message}`);
    }
  }

  /**
   * Generate QR code with custom logo/image embedded
   */
  async generateReferralQRWithLogo(referralCode, logoBuffer, options = {}) {
    try {
      // First generate the base QR code
      const qrResult = await this.generateReferralQR(referralCode, options);
      
      // Note: Actual logo embedding would require additional libraries
      // This is a placeholder for the logo embedding functionality
      // For production, use: qrcode-terminal or canvas-based approach

      return {
        success: true,
        ...qrResult,
        hasLogo: false,
        message: 'Logo embedding requires additional processing'
      };
    } catch (error) {
      throw new Error(`Failed to generate QR with logo: ${error.message}`);
    }
  }

  /**
   * Generate QR code with expiry time (for temporary codes)
   */
  async generateTemporaryQR(referralCode, expiryMinutes = 60, options = {}) {
    try {
      const tempId = uuidv4();
      const expiryTime = new Date(Date.now() + expiryMinutes * 60 * 1000);
      
      // Create a temporary URL with expiry
      const baseUrl = process.env.API_BASE_URL || 'https://coopvest.app';
      const tempUrl = `${baseUrl}/register?ref=${referralCode}&temp=${tempId}&expires=${expiryTime.toISOString()}`;

      const qrResult = await this.generateDataURL(tempUrl, options);

      return {
        success: true,
        referralCode,
        temporaryId: tempId,
        expiresAt: expiryTime,
        qrCode: qrResult.data,
        format: 'png'
      };
    } catch (error) {
      throw new Error(`Failed to generate temporary QR: ${error.message}`);
    }
  }

  /**
   * Validate a QR code data
   */
  validateQRData(qrData) {
    try {
      // Check if it's a valid URL
      const url = new URL(qrData);
      
      // Verify it contains our domain
      const baseUrl = process.env.API_BASE_URL || 'https://coopvest.app';
      const baseHostname = new URL(baseUrl).hostname;
      
      if (!url.hostname.includes(baseHostname)) {
        return {
          valid: false,
          error: 'QR code is not from Coopvest'
        };
      }

      // Extract referral code
      const referralCode = url.searchParams.get('ref');
      if (!referralCode) {
        return {
          valid: false,
          error: 'No referral code found in QR'
        };
      }

      // Check for temporary code
      const tempId = url.searchParams.get('temp');
      const expires = url.searchParams.get('expires');

      if (tempId && expires) {
        const expiryDate = new Date(expires);
        if (new Date() > expiryDate) {
          return {
            valid: false,
            error: 'QR code has expired',
            referralCode
          };
        }
      }

      return {
        valid: true,
        referralCode,
        isTemporary: !!tempId,
        source: url.searchParams.get('source')
      };
    } catch (error) {
      return {
        valid: false,
        error: 'Invalid QR code format'
      };
    }
  }

  /**
   * Get QR code statistics for analytics
   */
  getQRStats() {
    return {
      defaultSize: this.defaultOptions.width,
      sizePresets: this.sizePresets,
      defaultColor: this.defaultOptions.color,
      supportedFormats: ['png', 'svg', 'buffer'],
      errorCorrectionLevels: ['L', 'M', 'Q', 'H']
    };
  }

  // ==================== LOAN GUARANTOR QR METHODS ====================

  /**
   * Generate QR code data for loan guarantor request
   * Creates a signed, time-limited QR code with full loan details
   */
  generateLoanQRData(loanDetails) {
    const {
      loanId,
      applicantId,
      applicantName,
      applicantPhone,
      loanAmount,
      loanCurrency = 'NGN',
      loanTenure,
      interestRate,
      monthlyRepayment,
      totalRepayment,
      purpose
    } = loanDetails;

    // Create QR data structure (without signature first)
    const qrData = {
      version: '1.0',
      type: 'loan_guarantor',
      loanId,
      applicantId,
      applicantName,
      applicantPhone,
      loanAmount,
      loanCurrency,
      loanTenure,
      interestRate,
      monthlyRepayment,
      totalRepayment,
      purpose,
      createdAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + this.loanQRExpiryMs).toISOString(),
      qrId: `QR_${Date.now()}_${uuidv4().substring(0, 8)}`
    };

    // Generate HMAC signature
    const signature = this._generateSignature(qrData);
    qrData.signature = signature;

    return qrData;
  }

  /**
   * Generate QR code image for loan guarantor request
   */
  async generateLoanQRCode(loanDetails, options = {}) {
    try {
      // Generate QR data with signature
      const qrData = this.generateLoanQRData(loanDetails);
      const qrJsonString = JSON.stringify(qrData);

      // QR options for loan QR (higher error correction for reliability)
      const qrOptions = {
        width: options.size || this.sizePresets.medium,
        errorCorrectionLevel: options.errorCorrection || 'H', // High error correction
        margin: options.margin || 2,
        color: options.color || {
          dark: '#1B5E20',  // Coopvest green
          light: '#FFFFFF'
        }
      };

      // Generate QR code as data URL
      const result = await this.generateDataURL(qrJsonString, qrOptions);

      return {
        success: true,
        qrData: qrData,
        qrCode: result.data,
        format: 'png',
        size: qrOptions.width,
        message: 'QR code generated successfully. Valid for 7 days.'
      };
    } catch (error) {
      throw new Error(`Failed to generate loan QR code: ${error.message}`);
    }
  }

  /**
   * Generate loan QR code as buffer for direct file output
   */
  async generateLoanQRBuffer(loanDetails, options = {}) {
    try {
      const qrData = this.generateLoanQRData(loanDetails);
      const qrJsonString = JSON.stringify(qrData);

      const qrOptions = {
        width: options.size || this.sizePresets.medium,
        errorCorrectionLevel: 'H',
        margin: 2,
        color: {
          dark: '#1B5E20',
          light: '#FFFFFF'
        },
        ...options
      };

      const result = await this.generateBuffer(qrJsonString, qrOptions);

      return {
        success: true,
        qrData: qrData,
        buffer: result.buffer,
        format: 'png',
        size: qrOptions.width
      };
    } catch (error) {
      throw new Error(`Failed to generate loan QR buffer: ${error.message}`);
    }
  }

  /**
   * Validate loan QR code data and verify signature
   */
  validateLoanQRData(qrData) {
    try {
      // Check if data has required fields
      const requiredFields = [
        'version', 'type', 'loanId', 'applicantId', 'applicantName',
        'loanAmount', 'loanTenure', 'createdAt', 'expiresAt', 'qrId', 'signature'
      ];

      for (const field of requiredFields) {
        if (!qrData[field]) {
          return {
            valid: false,
            error: `Missing required field: ${field}`
          };
        }
      }

      // Verify QR type
      if (qrData.type !== 'loan_guarantor') {
        return {
          valid: false,
          error: 'Invalid QR code type'
        };
      }

      // Check version
      if (qrData.version !== '1.0') {
        return {
          valid: false,
          error: 'Unsupported QR code version'
        };
      }

      // Check expiry
      const expiryDate = new Date(qrData.expiresAt);
      if (new Date() > expiryDate) {
        return {
          valid: false,
          error: 'QR code has expired',
          expiredAt: qrData.expiresAt
        };
      }

      // Verify signature
      const { signature, ...dataWithoutSignature } = qrData;
      const expectedSignature = this._generateSignature(dataWithoutSignature);
      
      if (signature !== expectedSignature) {
        return {
          valid: false,
          error: 'Invalid QR code signature - may be tampered'
        };
      }

      return {
        valid: true,
        loanId: qrData.loanId,
        applicantId: qrData.applicantId,
        applicantName: qrData.applicantName,
        applicantPhone: qrData.applicantPhone,
        loanAmount: qrData.loanAmount,
        loanTenure: qrData.loanTenure,
        interestRate: qrData.interestRate,
        monthlyRepayment: qrData.monthlyRepayment,
        totalRepayment: qrData.totalRepayment,
        purpose: qrData.purpose,
        expiresAt: qrData.expiresAt,
        qrId: qrData.qrId
      };
    } catch (error) {
      return {
        valid: false,
        error: `Validation error: ${error.message}`
      };
    }
  }

  /**
   * Parse and validate a raw QR code string
   */
  parseAndValidateLoanQR(rawQRString) {
    try {
      const qrData = JSON.parse(rawQRString);
      return this.validateLoanQRData(qrData);
    } catch (error) {
      return {
        valid: false,
        error: 'Invalid QR code format - not valid JSON'
      };
    }
  }

  /**
   * Get loan QR statistics and configuration
   */
  getLoanQRStats() {
    return {
      expiryDays: 7,
      expiryMs: this.loanQRExpiryMs,
      defaultSize: this.sizePresets.medium,
      sizePresets: this.sizePresets,
      errorCorrectionLevel: 'H (High)',
      supportedFormats: ['png', 'svg', 'buffer', 'dataURL'],
      qrDataVersion: '1.0',
      qrTypes: ['loan_guarantor']
    };
  }
}

module.exports = new QRCodeService();