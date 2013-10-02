# native
require 'Logger'
require 'fileutils'

# gems
require 'git'
require 'json'

class Nyx

	VERSION = '1.1.0'

	def compile_scripts(args = nil)
		puts "  todo: compile scripts code"
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
			print "   - keep: #{fileidx} files processed (#{removed} removed)"
			Dir.glob("#{srcpath}/**/*", File::FNM_DOTMATCH) do |file|
				basename = File.basename(file)
				next if basename == '.' or basename == '..'
				fileidx += 1
				print (' ' * 79) + "\r"
				print "   - keep: #{fileidx} files processed (#{removed} removed)"
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
	end#def

	def do_cleanup_style(dirpath, conf, silent)
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
						if (silent)
							puts "   moving  #{file.gsub(basedir, '')} => #{rootfile.gsub(basedir, '')}"
						end#if
						if ! File.exist? rootfile
							begin
								# FileUtils.cp_r(file, rootfile)
								FileUtils.mkdir(rootfile)
							rescue
								puts "    failed to copy directory!"
							end#rescue
						end
					elsif ! File.directory?(file)
						if (silent)
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

		if (silent)
			puts
		end
	end#def

#
# Helpers
#

	def mjolnir_config(path, configname)
		# located mjolnir.php or etc/mjolnir.php
		bootstrap_path = self.locate_up(path, 'etc/mjolnir.php')
		if bootstrap_path == nil
			bootstrap_path = self.locate_up(path, 'mjolnir.php')
		end#if

		if bootstrap_path == nil
			self.fail 'Failed to locate mjolnir bootstrap file.'
		end#if

		json_config = `php -r "chdir('#{path}'); require '#{bootstrap_path}'; echo json_encode(include '#{configname}');"`;
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
