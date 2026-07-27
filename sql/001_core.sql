-- 001_core.sql — shared imperial tables: audit log bus + persistent KV.
-- Requires MariaDB >= 10.9 (JSON functions, idempotent DDL).

CREATE TABLE IF NOT EXISTS `imperial_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resource` VARCHAR(48) NOT NULL,
  `category` VARCHAR(48) NOT NULL,          -- e.g. money, security, admin, gameplay
  `severity` TINYINT UNSIGNED NOT NULL DEFAULT 1, -- 1 info, 2 warn, 3 suspicious, 4 critical
  `citizenid` VARCHAR(50) NULL,
  `target_citizenid` VARCHAR(50) NULL,
  `action` VARCHAR(64) NOT NULL,
  `amount` BIGINT NULL,
  `data` LONGTEXT NULL CHECK (JSON_VALID(`data`)),
  PRIMARY KEY (`id`),
  KEY `idx_logs_citizenid` (`citizenid`),
  KEY `idx_logs_resource_action` (`resource`, `action`),
  KEY `idx_logs_severity_time` (`severity`, `created_at`),
  KEY `idx_logs_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Persistent key/value store for restart-safe state (cooldowns, queues, flags).
CREATE TABLE IF NOT EXISTS `imperial_kv` (
  `k` VARCHAR(96) NOT NULL,
  `v` LONGTEXT NULL CHECK (JSON_VALID(`v`)),
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('001_core');
