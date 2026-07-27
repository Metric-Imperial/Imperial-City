-- 002_businesses.sql — imperial_businesses.

CREATE TABLE IF NOT EXISTS `imperial_businesses` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `business_key` VARCHAR(48) NOT NULL,
  `label` VARCHAR(96) NOT NULL,
  `type` VARCHAR(32) NOT NULL,               -- restaurant, cafe, bar, nightclub, mechanic, dealership, store, gunstore, farm, warehouse, logistics, realestate
  `owner_citizenid` VARCHAR(50) NULL,        -- NULL = unowned / repossessed
  `balance` BIGINT NOT NULL DEFAULT 0,
  `lease_weekly` INT UNSIGNED NOT NULL DEFAULT 0,
  `lease_arrears` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `metadata` LONGTEXT NULL CHECK (JSON_VALID(`metadata`)),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_business_key` (`business_key`),
  KEY `idx_business_owner` (`owner_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_business_employees` (
  `business_id` INT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(96) NOT NULL DEFAULT '',
  `grade` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `wage` INT UNSIGNED NOT NULL DEFAULT 0,
  `hired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`business_id`, `citizenid`),
  KEY `idx_bemp_citizenid` (`citizenid`),
  CONSTRAINT `fk_bemp_business` FOREIGN KEY (`business_id`)
    REFERENCES `imperial_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_business_txns` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `business_id` INT UNSIGNED NOT NULL,
  `actor_citizenid` VARCHAR(50) NULL,
  `type` VARCHAR(24) NOT NULL,  -- deposit, withdraw, pos_sale, wage, tax, lease, transfer, adjust
  `amount` BIGINT NOT NULL,
  `balance_after` BIGINT NOT NULL,
  `reason` VARCHAR(160) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_btxn_business_time` (`business_id`, `created_at`),
  CONSTRAINT `fk_btxn_business` FOREIGN KEY (`business_id`)
    REFERENCES `imperial_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('002_businesses');
