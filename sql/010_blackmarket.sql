-- 010_blackmarket.sql — imperial_blackmarket: fencing, laundering, listings.

CREATE TABLE IF NOT EXISTS `imperial_blackmarket_listings` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `seller_citizenid` VARCHAR(50) NOT NULL,
  `item` VARCHAR(64) NOT NULL,
  `count` INT UNSIGNED NOT NULL,
  `price` INT UNSIGNED NOT NULL,
  `metadata` LONGTEXT NULL CHECK (JSON_VALID(`metadata`)),
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_bm_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_launder_jobs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `dirty_amount` INT UNSIGNED NOT NULL,
  `clean_amount` INT UNSIGNED NOT NULL,
  `ready_at` INT UNSIGNED NOT NULL,
  `collected` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_launder_citizen` (`citizenid`, `collected`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('010_blackmarket');
