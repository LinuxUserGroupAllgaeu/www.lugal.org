require 'fileutils'
require 'date'
require 'tzinfo'
require 'icalendar'
require 'icalendar/tzinfo'

include Icalendar

module Jekyll
  class CalendarPage < Page; end

  class CalendarGenerator < Generator
    def parseEventInfo(event)
        # Parse date
        startdate = Time.parse(event['startdate'])
        if event.has_key?('enddate')
          enddate = Time.parse(event['enddate'])
        else
          enddate = startdate
        end
        event['startdate'] = startdate
        event['enddate'] = enddate
    end

    def generate(site)
      timezones = Hash.new
      calendars = Hash.new
      for post in site.posts
        if post.data['event']
          event = post.data['event']
          parseEventInfo(event)
          unless calendars.has_key?(event['calendar'])
            cal = Calendar.new
            calendars[event['calendar']] = cal
          end
          cal = calendars[event['calendar']]
          unless event.has_key?('timezone')
            event['timezone'] = site.config['calendar_default_timezone']
          end
          unless timezones[event['calendar']]
            timezones[event['calendar']] = Array.new
          end
          unless timezones[event['calendar']].include?(event['timezone'])
            tz = TZInfo::Timezone.get(event['timezone'])
            timezone = tz.ical_timezone(event['starttime'])
            timezones[event['calendar']].push(event['timezone'])
            cal.add(timezone)
          end
          cal.event do
            dtstart event['startdate']
            dtend   event['enddate']
            description event['description']
            summary event['summary']
            url site.config['url'] + post.url
            location event['location']
            geo Geo.new(event['lat'], event['lon'])
          end
          post.data['eventinfo'] = event
        end
      end
      calendars.each do |name,calendar|
        calendar_dir = "#{site.config['calendar_dir']}/"
        full_path = File.join(site.dest, calendar_dir)
        calendar_name = "#{name}.ical"
        FileUtils.mkdir_p(full_path)
        File.open("#{full_path}/#{calendar_name}", "w") do |f|
          f.write(calendar.to_ical)
        end
        site.pages << Jekyll::CalendarPage.new(site, site.dest, calendar_dir, calendar_name)
      end
    end
  end

  class EventTag < Liquid::Tag
    def render(context)
      event = context['page']['eventinfo']
      if event
        template = "<div class='event'>
                  <div class='calendar'>
                    <div class='calendar-weekday'>#{event['startdate'].strftime("%A")}</div>
                    <div class='calendar-day'>#{event['startdate'].strftime("%e")}</div>
                  </div>
                  <div class='eventinfo'>
                    <ul>
                      <li>Beginn: #{event['startdate'].strftime("%d.%m.%y - %H:%M")}</li>
                      <li>Ende: #{event['enddate'].strftime("%d.%m.%y  - %H:%M")}</li>
                      <li>Ort: #{event['location']}</li>
                      <li>Thema: #{event['description']}</li>
                  </div>
                  <div class='calendar-map'>
                    {% map #{event['lat']} #{event['lon']} 18 \"#{event['location']}\" %}
                  </div>
                </div>"
        return Liquid::Template.parse(template).render
      end
    end
  end
end

Liquid::Template.register_tag('render_event', Jekyll::EventTag)
