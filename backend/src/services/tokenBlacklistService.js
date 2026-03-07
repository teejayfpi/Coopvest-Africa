/**
 * Token Blacklist Service
 * 
 * Manages JWT token blacklisting for logout/token invalidation
 * Uses Redis for storage (with in-memory fallback)
 */

const jwt = require('jsonwebtoken');

// In-memory fallback for when Redis is not available
const memoryBlacklist = new Map();

class TokenBlacklistService {
  constructor() {
    this.redisClient = null;
    this.useMemoryFallback = true;
    this.initialized = false;
    this.initPromise = null;
  }

  /**
   * Initialize Redis connection (ensure single initialization)
   */
  async init() {
    if (this.initialized) return;
    if (this.initPromise) return this.initPromise;

    this.initPromise = (async () => {
      try {
        if (process.env.REDIS_URL) {
          const redis = require('redis');
          this.redisClient = redis.createClient({
            url: process.env.REDIS_URL
          });
          
          this.redisClient.on('error', (err) => {
            console.error('Redis Client Error:', err);
            this.useMemoryFallback = true;
          });
          
          this.redisClient.on('connect', () => {
            console.log('Redis connected for token blacklist');
            this.useMemoryFallback = false;
          });
          
          await this.redisClient.connect();
        }
      } catch (error) {
        console.warn('Redis not available, using in-memory token blacklist');
        this.useMemoryFallback = true;
      }
      this.initialized = true;
    })();

    return this.initPromise;
  }

  /**
   * Add token to blacklist
   */
  async add(token, expiryTimestamp) {
    const ttl = Math.max(0, expiryTimestamp - Math.floor(Date.now() / 1000));
    
    if (this.useMemoryFallback || !this.redisClient) {
      memoryBlacklist.set(token, {
        expiry: expiryTimestamp
      });
      
      // Clean up expired entries periodically
      this.cleanupMemoryBlacklist();
      return;
    }

    try {
      await this.redisClient.setEx(`blacklist:${token}`, ttl, 'true');
    } catch (error) {
      console.warn('Redis error, falling back to memory:', error.message);
      this.useMemoryFallback = true;
      memoryBlacklist.set(token, {
        expiry: expiryTimestamp
      });
    }
  }

  /**
   * Check if token is blacklisted
   */
  async isBlacklisted(token) {
    if (this.useMemoryFallback || !this.redisClient) {
      const entry = memoryBlacklist.get(token);
      if (!entry) return false;
      
      // Check if expired
      if (entry.expiry && Date.now() > entry.expiry * 1000) {
        memoryBlacklist.delete(token);
        return false;
      }
      return true;
    }

    try {
      const result = await this.redisClient.get(`blacklist:${token}`);
      return result === 'true';
    } catch (error) {
      console.warn('Redis error, falling back to memory:', error.message);
      this.useMemoryFallback = true;
      const entry = memoryBlacklist.get(token);
      if (!entry) return false;
      
      if (entry.expiry && Date.now() > entry.expiry * 1000) {
        memoryBlacklist.delete(token);
        return false;
      }
      return true;
    }
  }

  /**
   * Remove token from blacklist (for potential un-blacklist scenarios)
   */
  async remove(token) {
    if (this.useMemoryFallback || !this.redisClient) {
      memoryBlacklist.delete(token);
      return;
    }

    try {
      await this.redisClient.del(`blacklist:${token}`);
    } catch (error) {
      console.warn('Redis error:', error.message);
      this.useMemoryFallback = true;
      memoryBlacklist.delete(token);
    }
  }

  /**
   * Clean up expired entries from memory blacklist
   */
  cleanupMemoryBlacklist() {
    const now = Date.now();
    for (const [token, entry] of memoryBlacklist.entries()) {
      if (entry.expiry && now > entry.expiry * 1000) {
        memoryBlacklist.delete(token);
      }
    }
  }

  /**
   * Get blacklist statistics
   */
  async getStats() {
    let memorySize = memoryBlacklist.size;
    let redisSize = 0;

    if (!this.useMemoryFallback && this.redisClient) {
      try {
        const keys = await this.redisClient.keys('blacklist:*');
        redisSize = keys.length;
      } catch (e) {
        redisSize = 0;
      }
    }

    return {
      memoryBlacklistSize: memorySize,
      redisBlacklistSize: redisSize,
      usingRedis: !this.useMemoryFallback
    };
  }

  /**
   * Clear all blacklisted tokens (admin function)
   */
  async clearAll() {
    memoryBlacklist.clear();
    
    if (!this.useMemoryFallback && this.redisClient) {
      try {
        const keys = await this.redisClient.keys('blacklist:*');
        if (keys.length > 0) {
          await this.redisClient.del(keys);
        }
      } catch (error) {
        console.warn('Redis clear error:', error.message);
      }
    }
  }

  /**
   * Shutdown the service
   */
  async shutdown() {
    if (this.redisClient) {
      await this.redisClient.quit();
    }
    memoryBlacklist.clear();
  }
}

module.exports = new TokenBlacklistService();
