-- 004_turfs.sql — imperial_turfs territory control.

CREATE TABLE IF NOT EXISTS `imperial_turfs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `turf_key` VARCHAR(48) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `owner_gang_key` VARCHAR(48) NULL,  -- NULL = neutral
  `progress` TINYINT NOT NULL DEFAULT 0,   -- -100..100, sign indicates contesting direction
  `contested_by_gang_key` VARCHAR(48) NULL,
  `contest_started_at` INT UNSIGNED NULL,
  `last_capture_at` INT UNSIGNED NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_turf_key` (`turf_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_turf_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `turf_key` VARCHAR(48) NOT NULL,
  `gang_key` VARCHAR(48) NULL,
  `action` VARCHAR(32) NOT NULL,  -- contest_start, contest_cancel, captured, income
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_turflog_turf` (`turf_key`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('004_turfs');
