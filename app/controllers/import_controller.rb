class ImportController < ApplicationController
  before_filter :require_user
  layout "application"

  def index
  end

  def result
    begin
      data = YAML.load(params[:import][:uploaded_data]) #YAML.load(File.new('import.yaml','r').read)
      @topic = Topic.find(params[:import][:topic])
      error = false
      validate_data(data.dup)
      load_data(data)
    rescue
      error = $!.to_s
    end
    if error
      flash[:notice] = error
      redirect_to :action => :index
    end
  end

  private

  def parse_question(question_data)
    slice_question = question_data.split(/[.()]/)
    code = slice_question[0].strip
    points = slice_question[2].strip
    question = question_data.strip.sub(/^.*\.\s*\(\d+\)\s*/,"")
    return code.strip, points.to_i, question.strip
  end

  def validate_data(data_test)
    cnt = 0
    while true
      cnt += 1
      question_data = data_test.shift.to_s
      answers = data_test.shift
      error_string = "<br>Question no. #{cnt}<br>Question data: #{question_data}"
      if question_data and answers and (question_data.class != String or answers.class != Array)
        raise "Data series mismatch - strings (question) and array (answers) must be interlaced evenly!"+error_string
      end
      if !answers and question_data and !question_data.empty?
        raise "Data series mismatch - question without answers"+error_string
      end
      break if not answers
      answer_classes = answers.map{|x| x.class}.uniq
      if answer_classes.include?(Array) or answer_classes.include?(Hash)
        raise "Data series mismatch - Answers must contain strings only"+error_string
      end
      code, points, question = parse_question(question_data)
      raise "Question must not be empty"+error_string if question.strip.empty?
      raise "Question points must be > 0"+error_string if points < 1
      raise "Question must have a code"+error_string if code.strip.empty?
      one_correct = false
      answers.each do |answer_data|
        correct = false
        answer = answer_data.to_s.sub(/^\s*\*\s*/) {|m| correct = (m.strip=="*");''}
        one_correct = true if correct
      end
      # RELAX - need no correct answer
      # if answers.length==1 and answers[0].strip=="***"
      #   # doplnovaci otazka
      # else
      #   raise "Question must have at least 1 correct answer"+error_string if not one_correct
      # end
    end
  end
  
  def load_data(data)
    @imported_questions=[]
    @replaced_questions=[]
    while true
      question_data = data.shift.to_s
      answers = data.shift
      break if not answers
      points = 0
      replace_flag = false
      code, points, question = parse_question(question_data)
      Question.transaction do
        exists = Question.find_by_code(code)
        if exists
          q = exists
        else
          q = Question.new
        end
        q.code = code
        q.value = question.strip
        q.points = points
        q.topic = @topic
        q.save!
        alphabet = ('a'..'z').to_a
        if answers.length==1 and answers[0].strip=="***"
          # nedelat nic - doplnovaci otazka
        else
          q.answers = []
          answers.each_with_index do |answer_data,i|
            a = Answer.new
            correct = false
            answer = answer_data.to_s.strip.sub(/^[ \t]*\*[ \t]*/) {|m| correct = (m.strip=="*");''}
            a.value = answer
            a.correct = correct
            a.choice = alphabet[i]
            a.save!
            q.answers << a
          end
        end
        q.save!
        if replace_flag
          @replaced_questions << q
        else
          @imported_questions << q
        end
      end
    end
  end

end