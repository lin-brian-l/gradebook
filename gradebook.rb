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
	gb.execute("INSERT INTO #{@course} (name) VALUES (?)", [name])
  end

  #prompt for adding students
  def enter_name_ui
    puts "Enter a student's name."
    student = gets.chomp
    enter_name(@gb, student)
  end

  #add assignments and total # of pts
  def enter_assignment(gb, name, total)
    gb.execute("ALTER TABLE #{@course} ADD COLUMN #{name} VARCHAR(255)")
    gb.execute("ALTER TABLE #{@course}_total ADD COLUMN #{name} VARCHAR(255)")
    gb.execute("UPDATE #{@course}_total
      SET #{name} = '#{total}'
      ")
  end	

  #prompt for adding assignments and assigning totals
  def enter_assignment_ui
    puts "Enter the name of the assignment."
    assignment = gets.chomp
    puts "Enter the number of points this assignment is worth."
    total = gets.chomp
    enter_assignment(@gb, assignment, total)
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

  #calculate total # of points
  def calc_total
  	total = @gb.execute("SELECT * FROM #{@course}_total")
  	total_pts_array = total[0].values
  	index = 1
  	total_pts = 0
  	while index < total_pts_array.length/2
      total_pts += total_pts_array[index].to_i
      index += 1
  	end
  	total_pts
  end

  #create student-assignment hash
  def student_grades
  	gradebook = @gb.execute("SELECT * FROM #{@course}")
  	student_grades = {}
  	gradebook.each do |student|
  	  student_grades[student.values[1]] = {}
      index = 2 
      while index < (student.keys.length/2)
        student_grades[student.values[1]].merge!(student.keys[index] => student.values[index])
        # student_grades[student.values[1]][student.keys[index]] = student.values[index]
        # puts student_grades
        index += 1
      end
  	end
  	student_grades
  end

  #calculate total student points
  def calc_student_total(student_grades)
  	student_total = {}
    student_grades.each do |name, assignments|
      total = 0
      assignments.values.each { |score| total += score.to_i}
      student_total[name] = total
    end
    student_total
  end

  #calculate grades
  def calc_student_grade(student_total, total_pts)
  	student_percent = {}
  	student_grade = {}
  	grades = {
  	  97 => "A+", 
  	  94 => "A", 
  	  90 => "A-", 
  	  87 => "B+", 
  	  84 => "B", 
  	  80 => "B-", 
  	  77 => "C+",
  	  74 => "C",
  	  70 => "C-",
  	  67 => "D+",
  	  64 => "D", 
  	  60 => "D-", 
  	  59 => "F"
  	}

    student_total.each do |name, total|
      percent = total.to_f/total_pts.to_f * 100
      student_percent[name] = percent.round(2)
    end

    student_percent.each do |name, percent|
      grades.each do |cutoff, grade|
      	if percent >= cutoff.to_f
          student_grade[name] = [percent, grade]
          break if percent >= cutoff
      	end
      end
    end
    student_grade
  end

  #print student grades

  #print entire gradebook
  def print_gradebook
    gradebook = @gb.execute("SELECT * FROM #{@course}")
    puts "Grades for #{@course}:"
    gradebook.each do |student|
      puts "- #{student['name']}:"
      index = 2 
      while index < (student.keys.length/2)
        puts "-- #{student.keys[index]} - #{student.values[index]}"
        index += 1
      end
    end
  end



end

test = Gradebook.new("test")

# test.enter_name_ui
# test.enter_assignment_ui
# test.enter_score_ui
# test.calc_total
# test.print_gradebook
test.calc_student_grade(test.calc_student_total(test.student_grades), test.calc_total)