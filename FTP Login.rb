require 'tk'
require 'net/ftp'

def term(conn)
	if conn
		begin
			conn.quit
		ensure
			conn.close
		end
	end
	exit
end

def thud(title, message)
	Tk.messageBox('icon' => 'error', 'type' => 'ok',
				  'title' => title, 'message' => message)
end

class LoginWindow

	def genpair(row, text, width, ispwd=false)
	  tbut = TkLabel.new(@main, 'text' => text)	{
	  	grid('row' => row, 'column' => 0, 'sticky' => 'nse')
	  }			   			
      tvar = TkVariable.new('')
      lab = TkEntry.new(@main) {
      	background 'white'
      	foreground 'black'
      	textvariable tvar
      	width width
      	grid('row' => row, 'column' => 1, 'sticky' => 'nsw')
      }
      lab.configure('show' => '*') if ispwd

      return tvar
    end

    def do_login(mode)
    	host = @host.value
    	acct = @acct.value 
    	password = @password.value

    	if mode == 1 || (mode == 3 && acct == "" && password == "")
    		acct = 'anonymous'
    		if password == ""
    			password = 'anonymous'
    		end
    	end

    	if host == "" || acct == "" || password == ""
    		thud('Sin informacion de Login',
    			 "Tienes que dar un host y credenciales de login")
    		return
    	end

    	begin 
    		@conn = Net::FTP.new(host, acct, password)		 		
    		@conn.passive = true
    	rescue
    		thud("Fallo en el login", $!)
    		@conn = nil 
    		return
    	end
    	
    	@listwin.setconn(@conn)
    	@main.destroy()
    end
    
    def initialize(main, listwin, titfont, titcolor)
    	@main = TkToplevel.new(main)
    	@main.title('FTP Login')	

    	@listwin = listwin
    	@conn = nil

    	row = -1

    	toplab = TkLabel.new(@main) {
    		text "FTP Server Login"
    		justify 'center'
    		font titfont
    		foreground titcolor
    		grid('row' => (row += 1), 'column' => 0, 'columnspan' => 2,
				 'sticky' => 'news') 
    	}	

    	@host = genpair(row += 1, 'Host:', 25)

    	bframe = TkFrame.new(@main) {
    		grid('row' => (row += 1), 'column' => 0, 'columnspan' => 2,
    			 'sticky' => 'news')
    	}
    	TkButton.new(bframe, 'command' => proc { self.do_login(1) }) {
    		text 'Anon. Login'
    		pack('side' => 'left', 'expand' => 'yes', 'fill' => 'both')
    	}
    	TkButton.new(bframe, 'command' => proc { self.do_login(2) }) {
    		text 'User Login'
    		pack('side' => 'left', 'expand' => 'yes', 'fill' => 'both')
    	}
    	
    	@acct = genpair(row += 1, 'Login:', 15)
    	@password = genpair(row += 1, 'Password:', 15, true)

    	stop = TkButton.new(@main, 'command' => proc { term(@conn) }) {
    		text 'Exit'
    		grid('row' => (row += 1), 'column' => 0, 'columnspan' => 2,
    			 'sticky' => 'news')
    	}    		
    	@main.bind('Return', proc { self.do_login(3) })
    end
   end 	

class FileWindow < TkFrame
	def initialize(main)
		super
		titfont = 'arial 16 bold'
		titcolor = '#228800'
		@conn = nil
		TkLabel.new(self) {
			text 'FTP Download Agent'
			justify 'center'
			font titfont
			foreground titcolor
			pack('side' => 'top', 'fill' => 'x')
		}
		TkButton.new(self) {
			text 'Exit'
			command { term(@conn) }
			pack('side' => 'bottom', 'fill' => 'x')
		}
		@listarea = TkText.new(self) {
			height 10
			width 40
			cursor 'sb_left_arrow'
			state 'disabled'
			pack('side' => 'left')
			yscrollbar(TkScrollbar.new).pack('side' => 'right', 'fill' => 'y')
		}
		main.protocol('WM_DELETE_WINDOW', proc { term(@conn) })

		LoginWindow.new(main, self, titfont, titcolor)
	end
	
	def recolor(tag, color)	
		@listarea.tag_configure(tag, 'foreground' => color)
	end
	
	def load_dir(dir)
		if dir
			begin
				@conn.chdir(dir)
			rescue
				thud('No ' + dir, $!)
			end
			@statuslab.configure('text' => "[Cargando " + dir + "]")
		else
			@statuslab.configure('text' => '[Cargando Home Dir]')
		end
		update

		files = []
		dirs = []
		sawdots = false
		@conn.list() do |line|
			if line =~ /^[\-d]([r\-][w\-][x\-]){3}/
				parts = line.split(/\s+/, 9)
				if parts.lenght >= 9
					fn = parts.pop()
					sawdots = true if fn == '..'
					if parts[0][0..0] == 'd'
						dirs.push(fn)
					else
						files.push(fn)
					end
				end
			end
		end

		dirs.push('..') unless sawdots
		files.sort!
		dirs.sort!
		@listarea.configure('state' => 'normal')
		@listarea.delete('1.0', 'end')
		ct = 0
		while fn = dirs.shift
			tagname = "fn" + ct.to_s
			@listarea.insert('end', fn+"\n", tagname)
			@listarea.tag_configure(tagname, 'foreground' => '#4444FF')
			@listarea.tag_bind(tagname, 'Button-1',
							   proc { |f| self.load_dir(f) }, fn)
			@listarea.tag_bind(tagname, 'Enter',
							   proc { |t| self.recolor(t, '#0000aa') },
							   tagname)
			@listarea.tag_bind(tagname, 'Leave', 
							   proc { |t| self.recolor(t, '#4444ff') },
							   tagname)
			ct += 1
		end

		while fn = files.shift
			tagname = "fn" + ct.to_s
			@listarea.insert('end', fn+"\n", tagname)
			@listarea.tag_configure(tagname, 'foreground' => 'red')
			@listarea.tag_bind(tagname, 'Button-1',
							   proc { |f| self.dld_file(f) }, fn)
			@listarea.tag_bind(tagname, 'Enter',
							   proc { |t| self.recolor(t, '#880000') },
							   tagname)
			@listarea.tag_bind(tagname, 'Leave', 
							   proc { |t| self.recolor(t, 'red') },
							   tagname)
			ct += 1 
		end

		@listarea.configure('state' => 'disabled')
		begin
			loc = @conn.pwd()
		rescue
			thud('PWD Fallido', $!)
			loc = '???'
		end
		@statuslab.configure('text' => loc)
	end
	
	def dld_file(fn)
		@statuslab.configure('text' => "[Recibiendo " + fn + "]")
		update

		begin
			@conn.getbinaryfile(fn)
		rescue
			thud('DLD Fallido', fn + ': ' + $!)
			@statuslab.configure('text' => '')
		else
			@statuslab.configure('text' => 'Got ' + fn)
		end
	end

	def setconn(conn)
		@conn = conn
		load_dir(nil)
	end
end

BG = '#E6E6FA'
root = TkRoot.new('background' => BG) { title "FTP Download" }
TkOption.add("*background", BG)
TkOption.add("*activebackground", '#FFE6FA')
TkOption.add("*foreground", '#0000FF')
TkOption.add("*activebackground", '#0000FF')
FileWindow.new(root).pack()
Tk.mainloop