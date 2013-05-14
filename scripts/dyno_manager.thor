require "heroku-api"

class DynoManager < Thor
  desc "scale_down API_KEY APP_NAME", "Scales down any dynos that are not in use."
  def scale_down(api_key, app_name)

    heroku = Heroku::API.new(:api_key => api_key)
    procs = heroku.get_ps(app_name).body


    procs.each do |p|

      proc_name = p["process"]
      if proc_name.start_with? "celeryd" and Integer(p["elapsed"]) >= 60 * 10 #10 minutes
        heroku.post_ps_scale(app_name, 'celeryd', 0)
        puts "Turning off celeryd"
      elsif proc_name.start_with? "web" and p["state"] === "idle"
        heroku.post_ps_scale(app_name, 'web', 0)
        puts "Turning off web"
      end

    end

  end
end
