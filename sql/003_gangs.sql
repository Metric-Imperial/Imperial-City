-- 003_gangs.sql — imperial_gangs (dynamic, DB-backed; qbx_core's static gang
-- config is untouched — see resource README for the compatibility approach).

CREATE TABLE IF NOT EXISTS `imperial_gangs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_key` VARCHAR(48) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `leader_citizenid` VARCHAR(50) NOT NULL,
  `balance` BIGINT NOT NULL DEFAULT 0,
  `reputation` INT UNSIGNED NOT NULL DEFAULT 0,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_key` (`gang_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_gang_members` (
  `gang_id` INT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(96) NOT NULL DEFAULT '',
  `rank` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),  -- one gang per player, enforced structurally
  KEY `idx_gmember_gang` (`gang_id`),
  CONSTRAINT `fk_gmember_gang` FOREIGN KEY (`gang_id`)
    REFERENCES `imperial_gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imperial_gang_txns` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang_id` INT UNSIGNED NOT NULL,
  `actor_citizenid` VARCHAR(50) NULL,
  `type` VARCHAR(24) NOT NULL,
  `amount` BIGINT NOT NULL,
  `balance_after` BIGINT NOT NULL,
  `reason` VARCHAR(160) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gtxn_gang_time` (`gang_id`, `created_at`),
  CONSTRAINT `fk_gtxn_gang` FOREIGN KEY (`gang_id`)
    REFERENCES `imperial_gangs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `imperial_migrations` (`migration`) VALUES ('003_gangs');
