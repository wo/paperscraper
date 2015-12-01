
SET NAMES 'utf8';

CREATE TABLE documents (
  document_id INT(11) UNSIGNED NOT NULL auto_increment,
  found_date DATETIME DEFAULT NULL,
  last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  authors VARCHAR(255) DEFAULT NULL,
  title VARCHAR(255) DEFAULT NULL,
  abstract TEXT DEFAULT NULL,
  length SMALLINT(6) UNSIGNED DEFAULT NULL,
  language VARCHAR(8) DEFAULT 'en',
  meta_confidence FLOAT(4,3) UNSIGNED DEFAULT NULL,
  PRIMARY KEY (document_id),
  KEY (found_date)
) ENGINE=InnoDB CHARACTER SET utf8;

CREATE TABLE locations (
  location_id INT(11) UNSIGNED NOT NULL auto_increment,
  url VARCHAR(255) NOT NULL,
  status SMALLINT(6) DEFAULT NULL,
  document_id INT(11) UNSIGNED DEFAULT NULL,
  filetype VARCHAR(8) DEFAULT NULL,
  filesize INT(10) UNSIGNED DEFAULT NULL,
  spamminess FLOAT(4,3) UNSIGNED DEFAULT NULL,
  last_checked DATETIME DEFAULT NULL,
  PRIMARY KEY (location_id),
  UNIQUE KEY url (url),
  KEY (document_id),
  KEY (last_checked)
) ENGINE=InnoDB CHARACTER SET utf8;

CREATE TABLE sources (
  source_id INT(11) UNSIGNED NOT NULL auto_increment,
  type SMALLINT(4) UNSIGNED NOT NULL DEFAULT 1,
  url VARCHAR(255) NOT NULL,
  status SMALLINT(6) DEFAULT NULL,
  crawl_depth TINYINT UNSIGNED NOT NULL DEFAULT 1,
  parent_id INT(11) UNSIGNED DEFAULT NULL,
  found_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_checked DATETIME DEFAULT NULL,
  default_author VARCHAR(128) DEFAULT NULL,
  name VARCHAR(128) DEFAULT NULL,
  content TEXT DEFAULT NULL,
  PRIMARY KEY (source_id),
  UNIQUE KEY (url),
  KEY (last_checked)
) ENGINE=InnoDB CHARACTER SET utf8;

CREATE TABLE links (
  source_id INT(11) UNSIGNED NOT NULL,
  location_id INT(11) UNSIGNED NOT NULL,
  anchortext VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (source_id, location_id),
  KEY (location_id),
  KEY (source_id)
) ENGINE=InnoDB CHARACTER SET utf8;

CREATE TABLE author_names (
  name_id INT(11) UNSIGNED NOT NULL auto_increment,
  name VARCHAR(64) NOT NULL,
  last_searched DATETIME DEFAULT NULL,
  is_name TINYINT UNSIGNED DEFAULT 1,
  PRIMARY KEY (name_id),
  UNIQUE KEY (name)
) ENGINE=InnoDB CHARACTER SET utf8;



DROP TABLE IF EXISTS docs;
CREATE TABLE docs (
  doc_id INT(11) UNSIGNED NOT NULL auto_increment,
  status SMALLINT(6) DEFAULT 1,
  url VARCHAR(255) NOT NULL,
  filetype VARCHAR(8) DEFAULT NULL,
  found_date DATETIME DEFAULT NULL,
  authors VARCHAR(255) DEFAULT NULL,
  title VARCHAR(255) DEFAULT NULL,
  abstract TEXT DEFAULT NULL,
  numwords SMALLINT(6) UNSIGNED DEFAULT NULL,
  source_url VARCHAR(255) DEFAULT NULL,
  source_name VARCHAR(255) DEFAULT NULL,
  meta_confidence FLOAT(4,3) UNSIGNED DEFAULT NULL,
  spamminess FLOAT(4,3) UNSIGNED DEFAULT NULL,
  content MEDIUMTEXT DEFAULT NULL,
  PRIMARY KEY (doc_id),
  UNIQUE KEY (url),
  KEY (found_date)
) ENGINE=InnoDB CHARACTER SET utf8;

DROP TABLE IF EXISTS topics;
CREATE TABLE topics (
  topic_id INT(11) UNSIGNED NOT NULL auto_increment,
  label VARCHAR(255) DEFAULT NULL,
  is_default TINYINT(1) UNSIGNED DEFAULT 0,
  PRIMARY KEY (topic_id),
  UNIQUE KEY (label),
  KEY (is_default)
) ENGINE=InnoDB CHARACTER SET utf8;

DROP TABLE IF EXISTS docs2topics;
CREATE TABLE docs2topics (
  doc_id INT(11) UNSIGNED NOT NULL,
  topic_id INT(11) UNSIGNED NOT NULL,
  strength FLOAT(4,3) UNSIGNED DEFAULT NULL,
  is_training TINYINT(1) UNSIGNED DEFAULT 0,
  PRIMARY KEY (doc_id, topic_id),
  KEY (doc_id),
  KEY (topic_id)
) ENGINE=InnoDB CHARACTER SET utf8;

INSERT INTO topics (label, is_default) VALUES ('Metaphysics', 1);
INSERT INTO topics (label, is_default) VALUES ('Epistemology', 1);
