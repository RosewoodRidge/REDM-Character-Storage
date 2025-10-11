-- =========================================
-- FULL INSTALL (new users)
-- =========================================
CREATE TABLE IF NOT EXISTS `character_storage` (
  `id`               INT(11)       NOT NULL AUTO_INCREMENT,
  `owner_charid`     INT(11)       NOT NULL,
  `storage_name`     VARCHAR(50)   NOT NULL,
  `pos_x`            FLOAT(10,6)   NOT NULL,
  `pos_y`            FLOAT(10,6)   NOT NULL,
  `pos_z`            FLOAT(10,6)   NOT NULL,
  `authorized_users` LONGTEXT      NULL,
  `authorized_jobs`  TEXT          NOT NULL DEFAULT '{}',
  `capacity`         INT(11)       NOT NULL DEFAULT 50,
  `created_at`       TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  `last_accessed`    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  `is_preset`        TINYINT(1)    NOT NULL DEFAULT 0,
  `money_balance`    DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `ledger_history`   LONGTEXT      NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `owner_charid` (`owner_charid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;


-- =========================================
-- UPGRADE EXISTING TABLE (1.0.5 → 1.0.6+)
-- =========================================
ALTER TABLE `character_storage`
  ADD COLUMN IF NOT EXISTS `authorized_jobs` TEXT NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS `last_accessed` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN IF NOT EXISTS `is_preset` TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `money_balance` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS `ledger_history` LONGTEXT NULL DEFAULT NULL;