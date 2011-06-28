require 'atom'

module HomeHelper

  RECENT_SIZE=5


  def recent_project_changes_hash

    projects=current_user.person.projects
    
    people=Person.find(:all,:order=>'updated_at DESC')
    selected_people=[]

    people.each do |p|      
      selected_people << p if !(projects & p.projects).empty?
      break if selected_people.size>=RECENT_SIZE
    end
    item_hash=classify_for_tabs(selected_people)

    classes=Seek::Util.persistent_classes.select do |c|
        c.is_isa? || c.is_asset?
    end

    classes << Event if Seek::Config.events_enabled

    classes.each do |c|
      valid=[]
      c.find(:all,:order=>'updated_at DESC').each do |i|
        valid << i if projects.include?(i.project) && (!i.authorization_supported? || i.can_view?(current_user))
        break if valid.size >= RECENT_SIZE
      end
      item_hash.merge! classify_for_tabs(valid)
    end

    item_hash

  end

  def recent_changes_hash

    item_hash=classify_for_tabs(Person.find(:all,:order=>'updated_at DESC',:limit=>RECENT_SIZE))
    item_hash.merge! classify_for_tabs(Project.find(:all,:order=>'updated_at DESC',:limit=>RECENT_SIZE))

    classes=Seek::Util.persistent_classes.select do |c|
        c.is_isa? || c.is_asset?
    end

    classes << Event if Seek::Config.events_enabled

    classes.each do |c|
      valid=[]
      c.find(:all,:order=>"updated_at DESC").each do |i|
        valid << i if !i.authorization_supported? || i.can_view?(current_user)
        break if valid.size>=RECENT_SIZE
      end
      item_hash.merge! classify_for_tabs(valid)
    end

    item_hash
  end

  def recently_downloaded_items time=1.month.ago, number_of_item=10
    activity_logs = ActivityLog.find(:all,:group => "activity_loggable_type, activity_loggable_id", :order => "count(*) DESC", :conditions => ["action = ? AND updated_at > ?", 'download', time])
    items = []
    activity_logs.each do |activity_log|
      items.push activity_log.activity_loggable if !activity_log.activity_loggable.nil?
    end
    items.take(number_of_item)
  end

  def recently_viewed_items time=1.month.ago, number_of_item=10
    activity_logs = ActivityLog.find(:all,:group => "activity_loggable_type, activity_loggable_id", :order => "count(*) DESC", :conditions => ["action = ? AND updated_at > ?", 'show', time])
    #take out only Asset and Publication log
    activity_logs = activity_logs.select{|activity_log| ['DataFile', 'Model', 'Sop', 'Publication'].include?(activity_log.activity_loggable_type)}
    items = []
    activity_logs.each do |activity_log|
      items.push activity_log.activity_loggable if !activity_log.activity_loggable.nil?
    end
    items.take(number_of_item)
  end

  # get multiple feeds from multiple sites
  def get_feed feed_url=nil
    unless feed_url.blank?
      #trim the url element
      feed_url.strip!
      begin
        feed = Atom::Feed.load_feed(URI.parse(feed_url))
      rescue
        feed = nil
      end
      feed
    end
  end

  #

  def filter_feeds_entries_with_chronological_order feeds, number_of_entries=10
    filtered_entries = []
    unless feeds.blank?
      feeds.each do |feed|
         entries = try_block{feed.entries}
         #concat the source of the entry in the entry title, used later on to display
         unless entries.blank?
           entries.each{|entry| entry.title<< "***#{feed.title}" if entry.title}
         end
         filtered_entries |= entries.take(number_of_entries) if entries
      end
    end
    filtered_entries.sort {|a,b| (try_block{b.updated} || try_block{b.published} || try_block{b.last_modified || 10.year.ago}) <=> (try_block{a.updated} || try_block{a.published} || try_block{a.last_modified} || 10.year.ago)}.take(number_of_entries)
  end

  
  def display_single_entry entry
      html=''
      unless entry.blank?
          #get the link of the entry
          entry_links = try_block{entry.links}
          entry_link = try_block{entry_links.alternate.href}
          entry_title, feed_title = (try_block{entry.title} || '').split('***')
          entry_date = try_block{entry.updated} || try_block{entry.published} || try_block{entry.last_modified}
          entry_summary = truncate(strip_tags(entry.summary),:length=>500)
          tooltip=tooltip_title_attrib("<p>#{entry_summary}</p><p class='feedinfo none_text'>#{entry_date.strftime('%c') unless entry_date.nil?}</p>")
          unless entry_title.blank? or entry_link.blank?
            html << "<li class='homepanel_item'>"
            html << link_to("#{entry_title}", "#{entry_link}", :title => tooltip, :target=>"_blank")
            html << "<div class='feedinfo none_text'>"
            html << feed_title
            html << " - #{time_ago_in_words(entry_date)} ago" unless entry_date.nil?
            html << "</div>"
            html << "</li>"
          end
      end
      html
  end

end
