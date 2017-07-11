class SurveyTrendsGenerator

=begin
 params :
    subject : SurveySubject
    population: user ids of the participants to generate data out of
=end
  def initialize(subject, user_population)
    @subject = subject
    @user_population = user_population
  end
  # check for results availability

  def individual_survey_result_over_time
    trend_data = []
    trend_data << header_columns

    date_labels(survey_attempt_dates).each do |date|
      trend_data << generate_trend_row(date, trend_data[0], survey_attempt_dates)
    end

    trend_data
  end
=begin
  output :
  => [[0] [[0] "Date", [1] "Infection Preventive Outbreak Control"],
      [1] [[0] "Jul 2016", [1] 96],
      [2] [[0] "Aug 2016",[1] 86]
=end
  def group_survey_result_over_time
    trend_data = [['Date', @subject.title]]

    date_labels(subject_attempt_dates).each do |date|
      trend_data << generate_trend_row(date, trend_data[0], subject_attempt_dates)
    end

    trend_data
  end

  def group_survey_result_right_over_wrong
    trend_data = []
    correct_percentages = []

    group_survey_result_over_time.each_with_index do |data, index|
      next if index == 0 # header
      correct_percentages << data.last
    end

    if correct_percentages.present?
       average_correct = correct_percentages.sum / correct_percentages.size
      trend_data << ['Correct Answers', average_correct]
      trend_data << ['Wrong Answers', 100 - average_correct]
    end

    trend_data
  end

  def has_available_individual_results?
    survey_attempt_dates.present?
  end

  def has_available_group_results?
    subject_attempt_dates.present?
  end

  private

  def survey_attempts_population
    @survey_attempts_involved ||= SurveyAttempts.where(survey_id: subject.survey_ids, participant_id: @user_population)
  end

  def header_columns
    @header_columns ||= ['Date'] + survey_attempt_dates.keys
  end

=begin
  output :
  {
    "Exclusion of Sick Children" => {
      2016-06-01 00:00:00 UTC => 1,
      2016-07-01 00:00:00 UTC => 3
    },
    "Infection Preventive Outbreak Control" => {
      2016-06-01 00:00:00 UTC => 3,
      2016-07-01 00:00:00 UTC => 7
    }
  }
=end
  def survey_attempt_dates
    @survey_attempt_dates ||= (
      @subject.surveys.inject({}) do |list, survey|
        attempts = attempts_per_survey([survey.id])

        if attempts.present?
          # get score percentage for every attempt groupings
          # formula : average of correct scores / average # of questions * 100
          attempts.each_pair{|date, score| attempts[date] = (score / survey.questions.size * 100).to_i}

          list[survey.name] = attempts
        end
        list
      end
    )
  end

  def subject_attempt_dates
    @subject_attempt_dates ||= (
      scores_per_date = Hash.new{|h, k| h[k] = []}

      survey_attempt_dates.values.each do |date_hash|
        date_hash.each_pair do |date, score_percentage|
          scores_per_date[date] << score_percentage
        end
      end

      # get the average score per date
      scores_per_date.each_pair{|date, score| scores_per_date[date] = score.sum / score.size}
      if scores_per_date.present?
        {@subject.title => scores_per_date}
      else
        {}
      end
    )
  end

  def attempts_per_survey(survey_id)
    SurveyAttempts.where(survey_id: survey_id, participant_id: @user_population).group("DATE_TRUNC('month', created_at)").average('score')
  end

  def date_labels(attempt_dates)
    attempt_dates.values.map(&:keys).flatten.uniq.sort
  end

  def generate_trend_row(date, headers, attempt_dates)
    row = Array.new(headers.size, 0)
    row[0] = date.strftime('%b %Y')

    headers.each_with_index do |survey, index|
      next if index == 0

      row[index] = attempt_dates[survey][date] || 0
    end

    row
  end
end
