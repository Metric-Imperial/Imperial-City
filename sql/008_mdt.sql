-- 008_mdt.sql — imperial_dispatch call history + imperial_mdt records.

CREATE TABLE IF NOT EXISTS `imperial_dispatch_calls` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(16) NULL,
  `title` VARCHAR(96) NOT NULL,
  `description` VARCHAR(255) NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `jobs` VARCHAR(255) NOT NULL,      -- comma list, e.g. "police,ambulance"
  `priority` TINYINT UNSIGNED NOT NULL DEFAULT 3,
  `source_resource` VARCHAR(48) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `metadata` LONGTEXT NULL CHECK (JSON_VALID(`metadata`)),
  PRIMARY KEY (`id`),
  KEY `idx_dispatch_created` (`created_at`),
  KEY `idx_dispatch_jobs` (`jobs`(64))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_mdt_reports` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `department` VARCHAR(16) NOT NULL,  -- police, ambulance, fire
  `type` VARCHAR(24) NOT NULL,        -- incident, arrest, citation, warrant, bolo, note, medical, fire
  `title` VARCHAR(120) NOT NULL,
  `body` MEDIUMTEXT NOT NULL,
  `author_citizenid` VARCHAR(50) NOT NULL,
  `subject_citizenid` VARCHAR(50) NULL,
  `dispatch_call_id` BIGINT UNSIGNED NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `metadata` LONGTEXT NULL CHECK (JSON_VALID(`metadata`)),
  PRIMARY KEY (`id`),
  KEY `idx_mdt_dept_type` (`department`, `type`),
  KEY `idx_mdt_subject` (`subject_citizenid`),
  KEY `idx_mdt_created` (`created_at`),
  CONSTRAINT `fk_mdt_dispatch` FOREIGN KEY (`dispatch_call_id`)
    REFERENCES `imperial_dispatch_calls` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_mdt_charges` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `report_id` INT UNSIGNED NOT NULL,
  `charge_code` VARCHAR(24) NOT NULL,
  `label` VARCHAR(120) NOT NULL,
  `fine` INT UNSIGNED NOT NULL DEFAULT 0,
  `jail_months` DECIMAL(5,1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_mdtcharge_report` FOREIGN KEY (`report_id`)
    REFERENCES `imperial_mdt_reports` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_mdt_warrants` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `subject_citizenid` VARCHAR(50) NOT NULL,
  `reason` VARCHAR(255) NOT NULL,
  `issued_by` VARCHAR(50) NOT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_warrant_subject` (`subject_citizenid`, `active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_mdt_bolos` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(120) NOT NULL,
  `description` VARCHAR(255) NOT NULL,
  `plate` VARCHAR(12) NULL,
  `author_citizenid` VARCHAR(50) NOT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_bolo_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_mdt_audit` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `department` VARCHAR(16) NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  `target` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mdtaudit_citizen` (`citizenid`),
  KEY `idx_mdtaudit_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('008_mdt');
