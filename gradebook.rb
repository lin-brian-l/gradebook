# Create a gradebook which allows the following:
# - Track for multiple courses : DONE
# - Create UI : WIP
# - Add names to the gradebook : DONE
# - Add assignments (and point values) to the gradebook : DONE
# - Enter/edit point values : DONE
# - Calculate grades : DONE
# - Create & test exporter method to trim extra key/value pairs : DONE


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

  #clean export_all method
  def export_clean
    export_all = @gb.execute("SELECT * FROM #{@course}")
    export = []
    export_all.each do |student|
      export << student.delete_if { |key, value| (0...student.keys.length).include?(key) }
    end
    export
  end

  #clean export_total method
  def export_total_clean
    export_total_raw = @gb.execute("SELECT * FROM #{@course}_total")
    export_total = export_total_raw[0]
    export_total.delete_if { |key, value| (0...export_total.keys.length).include?(key) }
    export_total
  end 

  #add students
  def enter_name(gb, name)
	  gb.execute("INSERT INTO #{@course} (name) VALUES (?)", [name])
  end

  #generate roster
  def make_roster
    roster = export_clean
    roster.each { |student| puts "#{student.values[0]} | #{student.values[1]}" }
  end

  #prompt for adding students
  def enter_name_ui
    puts "Here is your current roster:"
    make_roster
    puts "Enter your new student's name."
    student = gets.chomp
    enter_name(@gb, student)
  end

  #add assignments and total # of pts
  def enter_assignment(gb, name, total)
    gb.execute("ALTER TABLE #{@course} ADD COLUMN #{name} VARCHAR(255)")
    gb.execute("UPDATE #{@course} SET #{name} = 0")
    gb.execute("ALTER TABLE #{@course}_total ADD COLUMN #{name} VARCHAR(255)")
    gb.execute("UPDATE #{@course}_total
      SET #{name} = '#{total}'
      ")
  end	

  #create array of assignment names
  def create_assignment_names
    names_hash = export_total_clean
    assignment_names = names_hash.keys
    assignment_names.delete_at(0)
    assignment_names
  end

  #prompt for adding assignments and assigning totals
  def enter_assignment_ui
    puts "The following are all of the existing assignments:"
    print create_assignment_names
    puts "\nEnter the name of a new assignment."
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

  #prompt for entering score on assignment for individual student
  def enter_score_ui
    puts "Here is the current gradebook:"
    print_gradebook
    puts "Enter the name of the student whose score you want to edit."
    student = gets.chomp
    puts "Enter the name of the assignment you want to edit scores for."
    assignment = gets.chomp
    puts "Enter the #{student}'s score on #{assignment}."
    score = gets.chomp
    enter_score(@gb, assignment, score, student)
    puts "Here are #{student}'s updated grades:"
    print_student_gradebook(student)
  end  

  #assignment commands UI
  def assignment_ui
    assignment_choice = nil
    until (1..2).include?(assignment_choice)
      puts "Would you like to (1) create a new assignment or (2) edit scores for an existing assignment?"
      assignment_choice = gets.chomp.to_i
      case assignment_choice
      when 1
        enter_assignment_ui
      when 2
        enter_score_ui
      else
        puts "Please enter the number 1 or 2."
      end
    end
  end

  #calculate total # of points
  def calc_total
  	total = export_total_clean
  	total_pts_array = total.values
  	index = 1
  	total_pts = 0
  	while index < total_pts_array.length
      total_pts += total_pts_array[index].to_i
      index += 1
  	end
  	total_pts
  end

  #create student-assignment hash
  def student_grades_hash
    gradebook = export_clean
    student_grades = {}
    gradebook.each do |student|
      student_grades[student.values[1]] = {}
      index = 2
      while index < student.keys.length
        student_grades[student.values[1]].merge!(student.keys[index] => student.values[index])
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

  #calculate student grades
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
  	  0 => "F"
  	}

    student_total.each do |name, total|
      percent = total.to_f/total_pts.to_f * 100
      student_percent[name] = percent.round(2)
    end

    student_percent.each do |name, percent|
      grades.each do |cutoff, grade|
      	if percent >= cutoff.to_f
          student_grade[name] = [student_total[name], percent, grade]
          break if percent >= cutoff
      	end
      end
    end
    student_grade
  end

  #print all student grades
  def print_grades
  	all_grades = calc_student_grade(calc_student_total(student_grades_hash), calc_total)
    all_grades.each do |name, grade|
      puts "#{name} scored #{grade[1]}%, earning a #{grade[2]}."
    end
  end

  #print entire gradebook
  def print_gradebook
    total_hash = export_total_clean
    gradebook = export_clean
    puts "Grades for #{@course}:"
    gradebook.each do |student|
      puts "- #{student['name']}:"
      index = 2 
      while index < (student.keys.length)
        puts "-- #{student.keys[index]} - #{student.values[index]}/#{total_hash.values[index-1]}"
        index += 1
      end
      total = calc_total
      student_total = calc_student_grade(calc_student_total(student_grades_hash), total)[student['name']]    
      puts "-- Total : #{student_total[0]}/#{total}"
      puts "-- Percent : #{student_total[1]}"
      puts "-- Grade: #{student_total[2]}"
    end
  end

  #print one student's grades
  def print_student_gradebook(student)
    total_hash = export_total_clean
    gradebook = student_grades_hash
    index = 1
    puts "Grades for #{student} in #{@course}:"
    while index < total_hash.values.length
      puts "- #{gradebook[student].keys[index-1]} : #{gradebook[student].values[index-1]}/#{total_hash.values[index]}"
      index += 1
    end
    student_total = calc_student_grade(calc_student_total(student_grades_hash), calc_total)[student]
    total = calc_total
    puts "- Total : #{student_total[0]}/#{total}"
    puts "- Percent : #{student_total[1]}"
    puts "- Grade: #{student_total[2]}"
  end

  #print commands UI
  def print_ui
    print_choice = nil
    until (1..3).include?(print_choice) 
      puts "Would you like to print (1) the entire gradebook, (2) all final grades, or (3) one student's grades?"
      print_choice = gets.chomp.to_i
      case print_choice
      when 1
        print_gradebook
      when 2
        print_grades
      when 3
        puts "Which student's grades would you like to see?"
        student = gets.chomp
        print_student_gradebook(student)
      else
        puts "Please enter a number from 1 - 3."
      end
    end
  end

end

# puts "What gradebook would you like to open?"
# course = gets.chomp

test = Gradebook.new("test")

# test.enter_name_ui
# test.enter_assignment_ui
# test.enter_score_ui
# test.calc_total
# test.print_gradebook
# print test.export_total_clean
# print test.print_grades
# test.print_grades
# test.enter_name_ui
# print test.student_grades_hash
# print test.calc_student_total(test.student_grades_hash)
# print test.calc_student_grade(test.calc_student_total(test.student_grades_hash), test.calc_total)

# test.print_ui

# print test.create_assignment_names
# test.print_student_gradebook("Brian")
test.assignment_ui