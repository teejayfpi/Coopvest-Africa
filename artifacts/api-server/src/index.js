const app = require('./app');

const PORT = process.env.PORT || 8080;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Coopvest API server running on port ${PORT}`);
  console.log(`Health check: GET /api/v1/healthz`);
  console.log(`Auth endpoints: POST /api/v1/auth/{register,login,verify-email,...}`);
});
