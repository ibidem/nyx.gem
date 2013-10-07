# native
require 'Logger'
require 'fileutils'
require 'net/http'
require 'fileutils'

# gems
require 'git'
require 'json'
require 'zip/zipfilesystem'
require 'fssm'

class Nyx

	VERSION = '1.3.0'

	def compile_scripts(args = nil)

		# @todo CLEANUP properly read "silent" parameter

		if args != nil
			if args.length != 0
				dirpath = args[0].sub(/(\/)+$/,'')+'/'
				silent = false
			else # no parameters, assume .
				dirpath = './'
				silent = false
			end#if
		else # direct invokation
			dirpath = './'
			silent = false
		end#if

		dirpath = File.expand_path(dirpath) + '/'

		if ! File.exist? dirpath
			puts '  Err: target directory does not exist.'
			return;
		end#if

		conf = self.mjolnir_config(dirpath, '+scripts.php');

		self.do_cleanup_scripts dirpath, conf, silent

		self.ensure_closure_compiler(dirpath)

		puts
		puts " Recompiling..."
		puts " ----------------------------------------------------------------------- "
		conf = self.read_script_configuration(dirpath);
		self.recompile_scripts(conf, dirpath);
		puts " >>> all files regenarated "

	end#def

	def read_script_configuration(dirpath)
		conf = self.mjolnir_config(dirpath, '+scripts.php');

		# normalize targeted common
		if ! conf['targeted-common'].is_a?(Array)
			temp = [];
			conf['targeted-common'].each do |key, file|
				temp.push(file)
			end#each
			conf['targeted-common'] = temp;
		end#if

		# normalize targeted mapping
		conf['targeted-mapping'].each do |key, files|
			if ! files.is_a?(Array) && ! files.is_a?(String)
				temp = [];
				files.each do |key, file|
					temp.push(file)
				end#each
				conf['targeted-mapping'][key] = temp;
			end#if
		end#each

		if conf['targeted-common'] == nil
			conf['targeted-common'] = [];
		else # not nil
			conf['targeted-common'] = conf['targeted-common'].find_all do |item|
				item !~ /(^[a-z]+:\/\/|^\/\/).*$/
			end#find_all
		end#def

		# remove aliased keys
		conf['targeted-mapping'].each do |key, files|
			if files.is_a? String
				conf['targeted-mapping'].delete(key);
			end#if
		end#each

		# include common files
		conf['targeted-mapping'].each do |key, files|
			files = files.find_all do |item|
				item !~ /(^[a-z]+:\/\/|^\/\/).*$/
			end#find_all
			conf['targeted-mapping'][key] = conf['targeted-common'].clone;
			files.each do |file|
				if ( ! conf['targeted-mapping'][key].include?(file))
					conf['targeted-mapping'][key].push(file)
				end#if
			end#each
		end#each

		# convert to paths
		conf['targeted-mapping'].each do |key, files|
			files = files.find_all do |item|
				item !~ /(^[a-z]+:\/\/|^\/\/).*$/
			end#find_all
			files.collect! do |file|
				'src/'+file+'.js';
			end#collect
			conf['targeted-mapping'][key] = files
		end#each

		# convert to paths
		files = conf['complete-mapping']
		files = files.find_all do |item|
			item !~ /(^[a-z]+:\/\/|^\/\/).*$/
		end#find_all
		files.collect! do |file|
			'src/'+file+'.js';
		end#collect
		conf['complete-mapping'] = files

		return conf
	end#def

	def watch_scripts(args = nil)
		puts "  todo: watch scripts code"
	end#def

	def compile_style(args = nil)

		# @todo CLEANUP properly read "silent" parameter

		if args != nil
			if args.length != 0
				dirpath = args[0].sub(/(\/)+$/,'')+'/'
				silent = false
			else # no parameters, assume .
				dirpath = './'
				silent = false
			end#if
		else # direct invokation
			dirpath = './'
			silent = false
		end#if

		if ! File.exist? dirpath
			puts '  Err: target directory does not exist.'
			return;
		end#if

		conf = self.mjolnir_config(dirpath, '+style.php');

		self.do_cleanup_style dirpath, conf, silent

		Kernel.exec('compass compile -c bin/etc/compass/production.rb --environment production')

	end#def

	def watch_style(path = nil)
		puts "  todo: watch scripts code"
	end#def

	def compile(args)
		if args.length != 0
			dirpath = args[0].sub(/(\/)+$/,'')+'/'
		else # no parameters, assume .
			dirpath = './'
		end#if

		if ! File.exist? dirpath
			self.fail 'Target directory does not exist.'
			return;
		end#if

		jsonconfigfile = dirpath+'nyx.json'
		if ! File.exist? jsonconfigfile
			self.fail 'Missing nyx.json file in target directory.'
			return;
		end#if

		conf = JSON.parse(open(jsonconfigfile).read)

		# ensure nyx.json interface isn't newer

		conf_interface = '1.0.0'
		if (conf != nil && conf.has_key?('interface'))
			conf_interface = conf['interface'];
		end#if

		self.check_interface_version(conf_interface, 'nyx.json');

		# core processing

		conf['cores'].each do |wpcoreconf|
			self.core dirpath, wpcoreconf
		end#each

		puts ""
		puts "  fin"
	end#def

	def version(args)
		puts "  #{Nyx::VERSION}"
	end#def

#
# Work methods
#

	def core(path, conf)
		Dir.chdir path
		corepath = conf['path'].sub(/(\/)+$/, '')

		puts "  processing #{corepath}"
		# remove the core if it exists
		FileUtils.rm_rf corepath
		# clone a fresh copy
		puts "  cloning #{conf['repo']} -> #{conf['version']}"
		g = Git.clone conf['repo'], corepath
		g.checkout conf['version']
		FileUtils.rm_rf corepath+'/.git'

		# process "keep" rules
		if conf.has_key? 'keep'
			srcpath = File.expand_path(corepath)
			keep = conf['keep']
			filecount = Dir["#{srcpath}/**/*"].length
			fileidx = 0
			removed = 0
			print "   - keep: #{fileidx} files processed (#{removed} deleted)"
			Dir.glob("#{srcpath}/**/*", File::FNM_DOTMATCH) do |file|
				basename = File.basename(file)
				next if basename == '.' or basename == '..'
				fileidx += 1
				print (' ' * 256) + "\r"
				print "   - keep: #{fileidx} files processed (#{removed} deleted)"
				filepath = File.expand_path(file)
				filesubpath = filepath.sub(srcpath, '').gsub(/^\//, '')

				keepfile = false
				keep.each do |path|
					if filesubpath.start_with? path
						keepfile = true
						break
					end#if
				end#each

				if ! keepfile
					FileUtils.rm_rf filepath
					removed += 1
				end#if
			end#glob
			puts
		end#if

		# process "ensure" rules
		if conf.has_key? 'ensure'
			srcpath = File.expand_path(corepath) + '/'
			ensure_rules = conf['ensure']
			print "   - ensuring files"
			ensure_rules.each do |depfiles, srcfiles|
				depfilespath = srcpath + depfiles.sub(/\/$/, '') + '/'
				srcfilespath = srcfiles.sub(/\/$/, '')
				Dir.glob("#{depfilespath}**/*", File::FNM_DOTMATCH) do |file|
					# skip parent and self symbols
					basename = File.basename(file)
					next if basename == '.' or basename == '..'
					# compute file paths
					filepath = File.expand_path(file)
					filesubpath = filepath.sub(depfilespath, '')
					srcfile = srcfilespath + '/' + filesubpath
					# skip directories
					next if File.directory?(filepath)
					# progress info
					print (' ' * 256) + "\r"
					prettysubpath = filepath.sub(srcpath, '')
					print "   - ensure: #{prettysubpath}"
					# write missing file
					if ! File.exist?(srcfile)
						text = File.read filepath
						FileUtils.mkpath File.dirname(srcfile)
						File.write srcfile, text
					end#if
				end#glob
			end#each
			print (' ' * 256) + "\r"
			puts "   - ensure: all dependencies resolved"
		end#if

		# process "remove" rules
		if conf.has_key? 'remove'
			removed = 0
			srcpath = File.expand_path(corepath) + '/'
			conf['remove'].each do |file|
				filepath = srcpath + file
				if File.exist? filepath
					removed += 1
					FileUtils.rm_rf filepath
				end#if
			end#each
			files_tr = removed != 1 ? 'files' : 'file';
			puts "   - remove: #{removed} #{files_tr} deleted"
		end#if

	end#def

	def do_cleanup_scripts(dirpath, conf, silent)
		if ( ! silent)
			puts
		end#if

		basedir = dirpath.gsub /\/$/, ''

		# cleanup config
		conf['root'].gsub! /[\/\\]$/, ''
		conf['sources'].gsub! /[\/\\]$/, ''

		rootdir = basedir+'/'+conf['root'];

		self.purge_dir(rootdir)

		# copy all files to the root
		srcdir = basedir+'/'+conf['sources'];

		Dir["#{srcdir}/**/*"].each do |file|
			if (file.to_s.gsub(srcdir.to_s, '') !~ /\/(test|tests|docs|demos|examples|demo|example)(\/|$)/)
				if file !~ /^\..*$/ && file !~ /^.*\.(js|json)$/ &&
					rootfile = rootdir + (file.gsub srcdir, '')
					# check if file is non-empty directory
					if File.directory?(file) && ! (Dir.entries(file) - %w[ . .. ]).empty?
						if ( ! silent)
							puts "   moving  #{file.gsub(basedir, '')} => #{rootfile.gsub(basedir, '')}"
						end#if
						FileUtils.cp_r(file, rootfile)
					else # file
						if ( ! silent)
							puts "   moving  #{file.gsub(basedir, '')} => #{rootfile.gsub(basedir, '')}"
						end#if
						FileUtils.cp(file, rootfile)
					end#if
				end#if
			end#if
		end#each

		if ( ! silent)
			puts
		end#if
	end#def

	def do_cleanup_style(dirpath, conf, silent)
		if ( ! silent)
			puts
		end#if

		basedir = File.expand_path(dirpath)

		# cleanup config
		conf['root'].gsub! /[\/\\]$/, ''
		conf['sources'].gsub! /[\/\\]$/, ''

		rootdir = basedir + '/' + conf['root'];

		self.purge_dir(rootdir)

		# copy all non .scss files to the root; compass only copies images/
		srcdir = basedir + '/' + conf['sources'];

		Dir["#{srcdir}/**/*"].each do |file|
			if (file.to_s.gsub(srcdir.to_s, '') !~ /\/(jquery|test|tests|docs|js|javascript|less|demos|examples|demo|example)(\/|$)/)
				if file !~ /^\..*$/ && file !~ /^.*\.(scss|sass|json|md)$/
					rootfile = rootdir + (file.gsub srcdir, '')
					# check if file is non-empty directory
					if File.directory?(file) && ! (Dir.entries(file) - %w[ . .. ]).empty?
						if ( ! silent)
							puts "   moving  #{file.gsub(basedir, '')} => #{rootfile.gsub(basedir, '')}"
						end#if
						if ! File.exist? rootfile
							begin
								# FileUtils.cp_r(file, rootfile)
								FileUtils.mkdir(rootfile)
							rescue
								puts "    failed to copy directory!"
							end#rescue
						end#if
					elsif ! File.directory?(file)
						if ( ! silent)
							puts "   moving  #{file.gsub(basedir, '')} => #{rootfile.gsub(basedir, '')}"
						end#if
						begin
							FileUtils.cp(file, rootfile)
						rescue
							puts "    failed to copy file!"
						end#rescue
					end#if
				end#if
			end#if
		end#each

		if ( ! silent)
			puts
		end#if
	end#def

	def ensure_closure_compiler(basedir)
		# ensure closure compiler jar is present
		tmpdir = basedir.gsub(/[\/\\]$/, '') + '/bin/tmp'
		if ! File.exists? tmpdir + '/compiler.jar'
			Dir.chdir tmpdir
			if ! File.exists? tmpdir+"/closure.zip"
				download("closure-compiler.googlecode.com", "/files/compiler-latest.zip", tmpdir+"/closure.zip")
			end
			Zip::ZipFile.open(tmpdir+"/closure.zip") do |zipfile|
				zipfile.each do |file|
					if file.name == 'compiler.jar'
						puts "extracting #{file}"
						zipfile.extract(file.name, tmpdir + '/compiler.jar')
					end#if
				end#each
			end#open
		end#def
		Dir.chdir basedir
	end#def

	def recompile_scripts(conf, dirpath)
		if (conf['mode'] == 'complete')
			self.regenerate_scripts('master', conf['complete-mapping'], conf)
		else # targeted mode
			conf['targeted-mapping'].each do |key, files|
				self.regenerate_scripts(key, files, conf)
			end#each
		end#if
	end#def

	def regenerate_scripts(key, files, conf)
		if conf['closure.flags'] != nil
			compiler_options = conf['closure.flags'].join ' '
		else # no flags
			compiler_options = ''
		end#if

		rootdir = conf['root'];
		if files.size > 0
			puts " compiling #{key}"
			`java -jar bin/tmp/compiler.jar #{compiler_options} --js #{files.join(' ')} --js_output_file ./#{rootdir}#{key}.min.js --create_source_map ./#{rootdir}#{key}.min.js.map --source_map_format=V3`;
		end
	end#def

	def process_scripts(r, conf)

		if r.eql? '+scripts.php'
			puts ' >>> recompiling all...'
			# reload confuration
			conf = self.read_script_configuration(dirpath);
			if conf['mode'] == 'complete'
				self.regenerate_scripts('master', conf['complete-mapping'])
			else # non-complete mode
				# regenerate all
				conf['targeted-mapping'].each do |key, files|
					self.regenerate_scripts(key, files)
				end#each
			end#if
		end

		if conf['mode'] == 'complete'

			conf['complete-mapping'].each do |file|
				if file.eql? r
					puts " >>> recompiling [complete-script]"
					# regenerate the closure
					self.recompile_scripts(conf, dirpath)
					break;
				end#if
			end#each

		else # non-complete mode

			# search configuration for file
			conf['targeted-mapping'].each do |key, files|
				files.each do |file|
					if file.eql? r
						puts " >>> recompiling [#{key}]"
						# regenerate the closure
						self.regenerate_scripts(key, files);
					end#if
				end#each
			end#each

		end#if

	end#def

#
# Helpers
#

	def download(domain, file, to)
		Net::HTTP.start(domain) do |http|
			resp = http.get(file)
			open(to, "wb") do |file|
				file.write(resp.body)
			end#open
		end#http.start
	end#def

	def mjolnir_config(path, configname)
		# located mjolnir.php or etc/mjolnir.php
		bootstrap_path = self.locate_up(path, 'etc/mjolnir.php')
		if bootstrap_path == nil
			bootstrap_path = self.locate_up(path, 'mjolnir.php')
		end#if

		if bootstrap_path == nil
			self.fail 'Failed to locate mjolnir bootstrap file.'
		end#if

		json_config = `php -r "chdir('#{path}'); require '#{bootstrap_path}'; echo json_encode(include '#{configname}');"`
		return JSON.parse json_config
	end#def

	def locate_up(path, filename)
		if File.exist?(path + filename)
			return path + filename
		else # didnt find file
			parent = File.expand_path(path + '..').sub /\/$/, ''
			rawfilepath = parent.sub /^[a-zA-Z]:/, ''
			if rawfilepath.length != 0
				return self.locate_up(parent + '/', filename)
			else # file system root
				return nil # failed to find file
			end#if
		end#if
	end#def

	# remove all non dot files
	def purge_dir(directory)
		Dir["#{directory}/*"].each do |file|
			next if file == '.' || file == '..'
			if File.directory? file
				self.purge_dir(File.expand_path(file))
				if (Dir.entries(file) - %w[ . .. ]).empty?
					Dir.rmdir file
				end#if
			elsif file !~ /^\..*$/ # ignore dot files
				FileUtils.rm_rf file, :noop => false, :verbose => false
			end#if
		end#each
	end#def

	def check_interface_version(interface, source)
		nyxi = Nyx::VERSION.split '.'
		jsoni = interface.split '.'

		if jsoni[0] != nyxi[0]
			self.failed_version_check interface, source
		else # major versions are equal
			if jsoni[1] > nyxi[1]
				# ie. json requires extra features
				self.failed_version_check interface, source
			elsif jsoni[1] == nyxi[1] && jsoni[2] > nyxi[2]
				# ie. potential problems with bugfix'es
				self.failed_version_check interface, source
			end#if
		end#if
	end#def

	def failed_version_check(interface, source)
		self.fail "Incompatible versions: #{source} @ #{interface} but nyx.gem @ #{Nyx::VERSION}"
	end#def

	def fail(msg)
		puts "  Err: #{msg}"
	end#def

end#class
