# Create a gradebook which allows the following:
# - Track for multiple courses
# - Add names to the gradebook
# - Add assignments (and point values) to the gradebook
# - Enter/edit point values
# - Calculate grades

#require gems
require 'sqlite3'

#create Gradebook class
class Gradebook

  def initialize(course)
	#create SQLite3 database
	@gb = SQLite3::Database.new("gradebook.db")
	@gb.results_as_hash = true
	@course = course

	#create gradebook table variable
    create_table = <<-SQL
    CREATE TABLE IF NOT EXISTS #{@course} (
      id INTEGER PRIMARY KEY,
      name VARCHAR(255)
      )
    SQL

    #create gradebook_total table variable
    create_table_total = <<-SQL
    CREATE TABLE IF NOT EXISTS #{@course}_total (
      name VARCHAR(255)
      )
    SQL

    #create "total" entry
    create_total_row = <<-SQL
    INSERT INTO #{@course}_total (name)
    VALUES ("total")
    SQL

    #create gradebooks (if not made already)
	@gb.execute(create_table)
	@gb.execute(create_table_total)

	#enter "total" entry if doesn't exist
    empty_check = @gb.execute("SELECT name FROM #{@course}_total")
    @gb.execute(create_total_row) if empty_check.empty? || !empty_check[0].has_value?("total")
    
  end

  #add students
  def enter_name(gb, name)
	@gb.execute("INSERT INTO #{@course} (name) VALUES (?)", [name])
  end

  #prompt for adding students
  def enter_name_ui
    puts "Enter a student's name."
    student = gets.chomp
    enter_name(@gb, student)
  end

  #add assignments
  def enter_assignment(gb, name)
    gb.execute("ALTER TABLE #{@course} ADD COLUMN #{name} VARCHAR(255)")
    gb.execute("ALTER TABLE #{@course}_total ADD COLUMN #{name} VARCHAR(255)")
  end	

  #prompt for adding assignments
  def enter_assignment_ui
    puts "Enter the name of the assignment."
    assignment = gets.chomp
    enter_assignment(@gb, assignment)
  end

  #enter score on assignment for individual student
  def enter_score(gb, assignment, score, name)
  	gb.execute("UPDATE #{@course} 
  		SET #{assignment} = '#{score}' 
  		WHERE name = '#{name}'")
  end

  #prompt for enter score on assignment for individual student
  def enter_score_ui
    puts "Enter the name of the assignment."
    assignment = gets.chomp
    puts "Enter the name of the student."
    student = gets.chomp
    puts "Enter the student's score on the assignment."
    score = gets.chomp
    enter_score(@gb, assignment, score, student)
  end

  #print gradebook
  def print_gradebook
    gradebook = @gb.execute("SELECT * FROM #{@course}")
    puts "Grades for #{@course}:"
    gradebook.each do |student|
      puts "- #{student['name']}:"
      assign_array = student.keys
      score_array = student.values
      i = 2 
      while i < (student.keys.length/2)
        puts "-- #{student.keys[i]} - #{student.values[i]}"
        i += 1
      end
    end
  end



end

test = Gradebook.new("test")

# test.enter_name_ui
# test.enter_assignment_ui
# test.enter_score_ui
# test.print_gradebook