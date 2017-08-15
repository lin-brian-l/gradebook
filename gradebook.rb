# Create a gradebook which allows the following:
# - Add names to the gradebook
# - Add assignments (and point values) to the gradebook
# - Enter/edit point values
# - Calculate grades

#require gems
require 'sqlite3'
require 'faker' #for testing purposes

#create SQLite3 database
gb = SQLite3::Database.new("gradebook.db")
gb.results_as_hash = true

#create table variable
create_table = <<-SQL
  CREATE TABLE IF NOT EXISTS gradebook(
    id INTEGER PRIMARY KEY,
    name VARCHAR(255)
  )
SQL

#create gradebook (if not made already)
gb.execute(create_table)