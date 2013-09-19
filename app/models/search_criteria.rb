class SearchCriteria

  SOLR_SPECIAL_CHARS = %w{@ # ! % $ \ ^ -}

  attr_accessor :index, :value, :join, :field, :field_display_name

  def initialize(params = {})
    @join = params[:join] || ""
    @field_display_name = params[:display_name] || ""
    @index = params[:index] || 0
    @field = params[:field] || ""
    @value = (params[:value] || "").strip
  end

  def self.create_advanced_criteria(criteria)
    SearchCriteria.new(:field => criteria[:field], :value => criteria[:value], :join => "AND", :index => criteria[:index].to_s)
  end

  def self.build_from_params(criteria_list)
    text_fields =  FormSection.all.map{ |form| form.all_searchable_fields }.flatten

    criteria_list.map do |index, criteria_params|
      field = text_fields.detect { |text_field| text_field.name == criteria_params[:field] }
      criteria_params.merge!(:display_name => field.display_name_for_field_selector,
                            :index => index,
                            :field_type => field.type)
      SearchCriteria.new(criteria_params)
    end.sort_by(&:index)
  end

  def self.build_enquiry_criteria(criteria_list)
    SearchCriteria.new(criteria_list)
  end

  def self.lucene_query(criteria_list)
    criteria_list = criteria_list.clone
    criteria = criteria_list.shift
    build_joins(criteria_list, criteria.to_lucene_query)
  end

  # for text based fields
  def to_lucene_query
    phrases = value.split(/\s+OR\s+/i)
    phrases.map do |phrase|
      query = phrase.split(/[ ,]+/) - SOLR_SPECIAL_CHARS
      query = query.delete_if{|word| word.empty?}
      query = query.map{|word| word.sub!(/^[@#!%$\^-]+/, '') || word}
      query = query.map {|word| "(#{field}_text:#{word.downcase}~ OR #{field}_text:#{word.downcase}*)"}.join(" AND ")
      "(#{query})"
    end.join(" OR ")
  end

  def self.dismax_query(criteria_list)
    puts criteria_list.inspect
    criteria_list = criteria_list.clone
    criteria = criteria_list.shift
    criteria.to_dismax_query
  end

  def to_dismax_query
    phrases = value.split(/\s+OR\s+/i)
    phrases.map do |phrase|
      query = phrase.split(/[ ,]+/) - SOLR_SPECIAL_CHARS
      query = query.delete_if{|word| word.empty?}
      query = query.map{|word| word.sub!(/^[@#!%$\^-]+/, '') || word}
      query = query.map {|word| "(#{word.downcase}~ OR #{word.downcase}*)"}.join(" OR ")
      "#{query}"
    end.join(" OR ")
  end

  private
  def self.build_joins(list, lucene_query)
    query = lucene_query.to_s
    criteria = list.shift

    return query if criteria.nil?

    return criteria.to_lucene_query if query.length == 0

    if criteria.join == "AND"
      query = "(#{query} AND #{criteria.to_lucene_query})"
      return build_joins(list, query)
    end

    if criteria.join.casecmp("OR") == 0
      return "#{query} OR #{build_joins(list, criteria.to_lucene_query)}"
    end
  end

end
