-- 006_drugs.sql — imperial_drugs lab framework.

CREATE TABLE IF NOT EXISTS `imperial_drug_labs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lab_key` VARCHAR(48) NOT NULL,
  `owner_type` ENUM('player','gang') NOT NULL DEFAULT 'player',
  `owner_id` VARCHAR(50) NULL,        -- citizenid or gang key
  `tier` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `contamination` TINYINT UNSIGNED NOT NULL DEFAULT 0, -- 0-100 abstract failure risk
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_lab_key` (`lab_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_drug_batches` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lab_id` INT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `product` VARCHAR(32) NOT NULL,
  `stage` TINYINT UNSIGNED NOT NULL DEFAULT 1, -- 1 gather-consumed,2 processing,3 refining,4 packaging,5 done
  `quality` TINYINT UNSIGNED NOT NULL DEFAULT 50,
  `started_at` INT UNSIGNED NOT NULL,
  `stage_ready_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_batch_lab` (`lab_id`),
  CONSTRAINT `fk_batch_lab` FOREIGN KEY (`lab_id`)
    REFERENCES `imperial_drug_labs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('006_drugs');
