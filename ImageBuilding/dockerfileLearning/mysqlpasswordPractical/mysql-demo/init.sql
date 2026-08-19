CREATE DATABASE IF NOT EXISTS trainingdb;

USE trainingdb;

CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    course VARCHAR(100)
);

INSERT INTO students (name, course)
VALUES
    ('Student01', 'Docker'),
    ('Student02', 'Kubernetes'),
    ('Student03', 'Azure');

