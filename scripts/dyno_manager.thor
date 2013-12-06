require 'heroku-api'
require 'pg'
require 'uri'

class DynoManager < Thor
  desc 'scale_down API_KEY APP_NAME', 'Scales down any dynos that are not in use.'

  def scale_down(api_key, app_name)

    heroku = Heroku::API.new(:api_key => api_key)
    procs = heroku.get_ps(app_name).body


    procs.each do |p|

      proc_name = p['process']
      if proc_name.start_with? 'celeryd' and Integer(p['elapsed']) >= 60 * 10 #10 minutes
        db_cn = heroku.get_config_vars(app_name).body['DATABASE_URL']
        begin
          db = URI.parse(db_cn)

          conn = PG.connect(:host => db.host,
                            :port => db.port,
                            :user => db.user,
                            :password => db.password,
                            :dbname => db.path[1..-1])

          res = Integer(conn.exec('SELECT COUNT(*) FROM djkombu_message WHERE visible = TRUE')[0]['count'])

          if res === 0
            heroku.post_ps_scale(app_name, 'worker', 0)
            puts 'Turning off worker'
          end
        ensure
          conn.close unless conn.nil?
        end

      elsif proc_name.start_with? 'web' and p['state'] === 'idle'
        heroku.post_ps_scale(app_name, 'web', 0)
        puts 'Turning off web'
      end

    end

  end
end
