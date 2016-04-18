# encoding: utf-8

=begin
    Bot LaPrimaire.org helps french citizens participate to LaPrimaire.org
    Copyright (C) 2016 Telegraph.ai

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
=end

require_relative 'navigation.rb'

module Democratech
	class LaPrimaireBot < Grape::API
		prefix PREFIX.to_sym
		format :json
		class << self
			attr_accessor :mandrill, :tg_client, :nav, :mixpanel
		end

		helpers do
			def authorized
				headers['Secret-Key']==SECRET
			end

			def send_msg_fb(msg)
				uri = URI.parse('https://graph.facebook.com')
				http = Net::HTTP.new(uri.host, uri.port)
				http.use_ssl = true
				#http.verify_mode = OpenSSL::SSL::VERIFY_NONE
				request = Net::HTTP::Post.new("/v2.6/me/messages?access_token=#{FBPAGEACCTOKEN}")
				request.add_field('Content-Type', 'application/json')
				request.body = JSON.dump(msg)
				a=http.request(request)
				puts a.inspect
			end

			def send_msg(id,msg,options)
				if options[:keep_kbd] then
					options.delete(:keep_kbd)
				else
					kbd = options[:kbd].nil? ? Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard: true) : options[:kbd] 
				end
				lines=msg.split("\n")
				buffer=""
				max=lines.length
				idx=0
				image=false
				kbd_hidden=false
				lines.each do |l|
					next if l.empty?
					idx+=1
					image=(l.start_with?("image:") && (['.jpg','.png','.gif','.jpeg'].include? File.extname(l)))
					if image && !buffer.empty? then # flush buffer before sending image
						writing_time=buffer.length/TYPINGSPEED
						LaPrimaireBot.tg_client.api.send_chat_action(chat_id: id, action: "typing")
						sleep(writing_time)
						LaPrimaireBot.tg_client.api.sendMessage(chat_id: id, text: buffer)
						buffer=""
					end
					if image then # sending image
						LaPrimaireBot.tg_client.api.send_chat_action(chat_id: id, action: "upload_photo")
						LaPrimaireBot.tg_client.api.send_photo(chat_id: id, photo: File.new(l.split(":")[1]))
					elsif options[:groupsend] # grouping lines into 1 single message # buggy
						buffer+=l
						if (idx==max) then # flush buffer
							writing_time=l.length/TYPINGSPEED
							LaPrimaireBot.tg_client.api.sendChatAction(chat_id: id, action: "typing")
							sleep(writing_time)
							LaPrimaireBot.tg_client.api.sendMessage(chat_id: id, text: buffer, reply_markup:kbd)
							buffer=""
						end
					else # sending 1 msg for every line
						writing_time=l.length/TYPINGSPEED
						writing_time=l.length/TYPINGSPEED_SLOW if max>1
						LaPrimaireBot.tg_client.api.sendChatAction(chat_id: id, action: "typing")
						sleep(writing_time)
						options[:chat_id]=id
						temp_web_page_preview_disabling=false
						if l.start_with?("no_preview:") then
							temp_web_page_preview_disabling=true
							l=l.split(':',2)[1]
							options[:disable_web_page_preview]=true
						end
						options[:text]=l
						if idx<max and not kbd_hidden then
							options[:reply_markup]=Telegram::Bot::Types::ReplyKeyboardHide.new(hide_keyboard: true)
							kbd_hidden=true
						elsif (idx==max)
							options[:reply_markup]=kbd
						end
						LaPrimaireBot.tg_client.api.sendMessage(options)
						options.delete(:disable_web_page_preview) if temp_web_page_preview_disabling
					end
				end
			end
		end

		get '/fbmessenger' do
			if params['hub.verify_token']==SECRET then
				return params['hub.challenge'].to_i
			else
				return "nope"
			end
		end

		post '/fbmessenger' do
			messaging_events=params['entry'][0].messaging
			messaging_events.each do |e|
				sender=e.sender.id
				if !e.message.nil? and !e.message.text.nil? then
					puts "sending msg"
=begin
					msg={
						"recipient"=>{"id"=>sender},
						"message"=> {
							"attachment"=> {
								"type"=> "template",
								"payload"=> {
									"template_type"=> "generic",
									"elements"=> [{
										"title"=> "First card",
										"subtitle"=> "Element #1 of an hscroll",
										"image_url"=> "http://messengerdemo.parseapp.com/img/rift.png",
										"buttons"=> [{
											"type"=> "web_url",
											"url"=> "https://www.messenger.com/",
											"title"=> "Web url"
										}, {
											"type"=> "postback",
											"title"=> "Postback",
											"payload"=> "Payload for first element in a generic bubble",
										}],
									},{
											"title"=> "Second card",
											"subtitle"=> "Element #2 of an hscroll",
											"image_url"=> "http://messengerdemo.parseapp.com/img/gearvr.png",
											"buttons"=> [{
												"type"=> "postback",
												"title"=> "Postback",
												"payload"=> "Payload for second element in a generic bubble",
											}],
										}]
								}
							}
						}
					}
=end
=begin
					msg={
						"recipient"=>{"id"=>sender},
						"message"=>{"text"=>"https://laprimaire.org/candidat/178159928076"}
					}
=end
					msg={
						"recipient"=>{
							"id"=>sender
						},
						"message"=>{
							"attachment"=>{
								"type"=>"template",
								"payload"=>{
									"template_type"=>"button",
									"text"=>"What do you want to do next?",
									"buttons"=>[
										{
											"type"=>"web_url",
											"url"=>"https://petersapparel.parseapp.com",
											"title"=>"Show Website"
										},
										{
											"type"=>"postback",
											"title"=>"Start Chatting",
											"payload"=>"USER_DEFINED_PAYLOAD"
										}
									]
								}
							}
						}
					}
					send_msg_fb(msg)
				elsif !e.postback.nil? then
					puts e.postback.payload
					msg={
						"recipient"=>{"id"=>sender},
						"message"=>{"text"=>"postback received: "+e.postback.payload}
					}
					send_msg_fb(msg)
				end
			end
		end

		post '/command' do
			error!('401 Unauthorized', 401) unless authorized
			begin
				Bot::Db.init()
				update = Telegram::Bot::Types::Update.new(params)
				msg,options=Democratech::LaPrimaireBot.nav.get(update.message,update.update_id)
				send_msg(update.message.chat.id,msg,options) unless msg.nil?
			rescue Exception=>e
				STDERR.puts "#{e.message}\n#{e.backtrace.inspect}"
				error! "Exception raised: #{e.message}", 200 # if you put an error code here, telegram will keep sending you the same msg until you die
			ensure
				Bot::Db.close()
			end
		end

		post '/' do
			begin
				Bot::Db.init()
				update = Telegram::Bot::Types::Update.new(params)
				msg,options=Democratech::LaPrimaireBot.nav.get(update.message,update.update_id)
				send_msg(update.message.chat.id,msg,options) unless msg.nil?
			rescue Exception=>e
				# Having external services called here was a VERY bad idea as exceptions would not be rescued, it would make the worker crash... good job stupid !
				STDERR.puts "#{e.message}\n#{e.backtrace.inspect}\n#{update.inspect}"
				error! "Exception raised: #{e.message}", 200 # if you put an error code here, telegram will keep sending you the same msg until you die
			ensure
				Bot::Db.close()
			end
		end
	end
end
