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
  def enter_name(name)
	  @gb.execute("INSERT INTO #{@course} (name) VALUES (?)", [name])
  end

  #delete students
  def delete_name(name)
    @gb.execute("DELETE FROM #{@course} WHERE name = (?)", [name])
  end

  #generate roster
  def make_roster
    roster_whole = export_clean
    roster = []
    roster_whole.each {|student| roster << [student.values[0], student.values[1]]}
    roster
  end

  def print_roster
    roster = make_roster
    roster.each {|student| puts "#{student[0]}: #{student[1]}"}
  end

  #check for existing students
  def existing_student?(name)
    roster = make_roster
    roster.each {|student| return true if student[1] == name}
    return false
  end

  #prompt for adding students
  def enter_name_ui
    flag = true
    until flag == false
      puts "Enter your new student's name. Type 'cancel' if you do not want to add a student."
      student = gets.chomp
      break if student == "cancel"
      flag = existing_student?(student)
      puts "Please enter the name of a new student." if flag == true
    end
    enter_name(student) if student != "cancel"
  end

  #prompt for deleting students
  def delete_name_ui
    flag = false
    until flag == true
      puts "Enter the name of the student you want to remove. Type 'cancel' if you do not want to remove a student."
      student = gets.chomp
      break if student == "cancel"
      flag = existing_student?(student)
      puts "Please enter the name of an existing student." if flag == false
    end
    delete_name(student) if student != "cancel"
  end

  #UI for student commands
  def student_ui
    student_repeat = nil
    until ['n', 99].include?(student_repeat)
      puts "Here is your current roster:"
      print_roster
      student_choice = nil
      until [1, 2, 99].include?(student_choice)
        puts "Would you like to (1) add a student or (2) remove a student? Type '99' to exit."
        student_choice = gets.chomp.to_i
        case student_choice
        when 1
          enter_name_ui
        when 2
          delete_name_ui
        when 99
          #do nothing
        else
          puts "Please enter the numbers 1, 2, or 99."
        end
      end
      student_repeat = student_choice
      until ["n", "y", 99].include?(student_repeat)
        puts "Do you need to add or remove more students? (y/n)"
        student_repeat = gets.chomp
        puts "Please enter 'y' or 'n'." if !["n", "y"].include?(student_repeat)
      end
    end
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
    enter_assignment_choice = nil
    until enter_assignment_choice == "n"
      enter_assignment_choice = nil
      puts "The following are all of the existing assignments:"
      assignment_array = create_assignment_names
      print assignment_array.sort!
      assignment_array << nil
      assignment = nil
      puts
      until !assignment_array.include?(assignment)
        puts "Enter the name of a new assignment. Type 'xcancelx' to cancel."
        assignment = gets.chomp
        puts "Please enter a new assignment." if assignment_array.include?(assignment)
      end
      break if assignment == 'xcancelx'
      puts "Enter the number of points this assignment is worth. Type 'cancel' to cancel."
      total = gets.chomp
      break if total == 'cancel'
      enter_assignment(@gb, assignment, total)
      until ['y', 'n'].include?(enter_assignment_choice)
        puts "Would you like to enter another assignment? (y/n)"
        enter_assignment_choice = gets.chomp
        puts "Please enter 'y' or 'n'." if !["y", "n"].include?(enter_assignment_choice)
      end  
    end
  end

  #enter score on assignment for individual student
  def enter_score(gb, assignment, score, name)
  	gb.execute("UPDATE #{@course} 
  	  SET #{assignment} = '#{score}' 
  	  WHERE name = '#{name}'")
  end

  #prompt for entering score on assignment for individual student
  def enter_score_ui
    enter_score_choice = nil
    until enter_score_choice == "n"
      enter_score_choice = nil
      puts "Here is the current gradebook:"
      print_gradebook
      flag = false
      until flag == true
        puts "Enter the name of the student whose score you want to edit. Type 'cancel' to cancel."
        student = gets.chomp
        break if student == "cancel"
        flag = existing_student?(student)
        puts "Please enter the name of an existing student." if flag == false
      end
      break if student == "cancel"
      puts "The following are all of the existing assignments:"
      assignment_array = create_assignment_names
      print assignment_array.sort!
      assignment = nil
      puts
      until assignment_array.include?(assignment)
        puts "Enter the name of the assignment you want to edit scores for. Type 'cancel' to cancel."
        assignment = gets.chomp
        break if assignment == 'cancel'
        puts "Please enter the name of an existing assignment." if !assignment_array.include?(assignment)
      end
      break if assignment == 'cancel'
      puts "Enter the #{student}'s score on #{assignment}. Type 'cancel' to cancel."
      score = gets.chomp
      break if score == 'cancel'
      enter_score(@gb, assignment, score, student)
      puts "Here are #{student}'s updated grades:"
      print_student_gradebook(student)
      until ["n", "y"].include?(enter_score_choice)
        puts "Would you like to edit another score? (y/n)"
        enter_score_choice = gets.chomp
        puts "Please enter 'y' or 'n'." if !["n", "y"].include?(enter_score_choice)
      end  
    end
  end  

  #assignment commands UI
  def assignment_ui
    assignment_repeat = nil
    until assignment_repeat == "n"
      assignment_repeat = nil
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
      until ["y","n"].include?(assignment_repeat)
        puts "Do you still need to create new assignments or edit scores for existing assignments? (y/n)"
        assignment_repeat = gets.chomp
        puts "Please enter 'y' or 'n'." if !["y","n"].include?(assignment_repeat)
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
      puts
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
    puts
  end

  #print commands UI
  def print_ui
    print_repeat = nil
    until print_repeat == "y"
      print_repeat = nil
      print_choice = nil
      until (1..3).include?(print_choice) 
        puts "Would you like to print (1) the entire gradebook, (2) all final grades, or (3) one student's grades?"
        print_choice = gets.chomp.to_i
        case print_choice
        when 1
          puts
          print_gradebook
        when 2
          puts
          print_grades
        when 3
          puts "Here is your roster:"
          print_roster
          puts "Which student's grades would you like to see?"
          student = gets.chomp
          puts
          print_student_gradebook(student)
        else
          puts "Please enter a number from 1 - 3."
        end
      end
      until ['y','n'].include?(print_repeat)
        puts
        puts "Are you done printing grades? (y/n)"
        print_repeat = gets.chomp
        puts "Please enter 'y' or 'n'." if !['y','n'].include?(print_repeat)
      end
    end
  end

end

# puts "What gradebook would you like to open?"
# course = gets.chomp

test = Gradebook.new("test")

# test.enter_name_ui
# test.delete_name_ui
# test.enter_assignment_ui
test.enter_score_ui
# test.calc_total
# test.print_gradebook
# print test.export_total_clean
# print test.print_grades
# test.print_grades
# test.enter_name_ui
# print test.student_grades_hash
# print test.calc_student_total(test.student_grades_hash)
# print test.calc_student_grade(test.calc_student_total(test.student_grades_hash), test.calc_total)
# test.enter_score_ui
# test.print_ui
# test.student_ui
# print test.create_assignment_names
# test.print_student_gradebook("Brian")
# test.assignment_ui
# print test.make_roster
# test.print_roster
# print test.existing_student?("false")