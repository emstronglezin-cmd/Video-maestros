module.exports = {
  apps: [
    {
      name: 'video-maestro-backend',
      script: './dist/app.js',
      instances: 1,
      exec_mode: 'fork',
      
      // Auto-restart configuration
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      
      // Environment
      env: {
        NODE_ENV: 'production',
      },
      
      // Logging
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: './logs/error.log',
      out_file: './logs/out.log',
      merge_logs: true,
      
      // Restart strategy
      min_uptime: '10s',
      max_restarts: 10,
      restart_delay: 4000,
      
      // Kill timeout
      kill_timeout: 5000,
      
      // Listen timeout
      listen_timeout: 10000,
      
      // Graceful shutdown
      wait_ready: false,
      shutdown_with_message: false,
    },
  ],
};
