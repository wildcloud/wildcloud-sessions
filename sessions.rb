# Copyright (C) 2011 Marek Jelen
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'bundler/setup'

require 'em-hiredis'
require 'goliath'

EventMachine.next_tick do
  REDIS = EM::Hiredis.connect
end

class Session < Goliath::API

  def response(env)
    send("handle_#{env['REQUEST_METHOD'].downcase}".to_sym, env)
    [200, {}, Goliath::Response::STREAMING]
  end

  def handle_get(env)
    action = REDIS.hget(env['HTTP_X_APPID'], env['REQUEST_URI'])
    action.callback do |value|
      env.stream_send(value)
      env.stream_close
    end
    action.errback do |error|
      puts error
      env.stream_send('FAIL')
      env.stream_close
    end
  end

  def handle_put(env)
    action = REDIS.hset(env['HTTP_X_APPID'], env['REQUEST_URI'], env['rack.input'].read)
    action.callback do
      env.stream_send('OK')
      env.stream_close
    end
    action.errback do |error|
      puts error
      env.stream_send('FAIL')
      env.stream_close
    end
  end

end
