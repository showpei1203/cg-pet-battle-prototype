#!/usr/bin/env ruby
require 'zlib'
require 'fileutils'
require 'digest'
require 'csv'

src, out = ARGV
abort "Usage: export_rmvx_scripts.rb Scripts.rvdata OUT_DIR" unless src && out
scripts = Marshal.load(File.binread(src))
FileUtils.mkdir_p(out)
rows = []
scripts.each_with_index do |entry, index|
  script_id, name, compressed = entry
  content = Zlib::Inflate.inflate(compressed)
  safe = name.to_s.gsub(/[\\\/:*?\"<>|]/, '_').gsub(/\s+/, '_')
  safe = 'BLANK' if safe.empty?
  filename = format('%03d__id-%s__%s.rb', index, script_id, safe[0,100])
  header = "# RMVX_SCRIPT_INDEX: #{index}\n# RMVX_SCRIPT_ID: #{script_id}\n# RMVX_SCRIPT_NAME: #{name}\n# RMVX_SOURCE_SHA256: #{Digest::SHA256.hexdigest(content)}\n\n"
  File.binwrite(File.join(out, filename), header + content)
  rows << [index, script_id, name, content.bytesize, Digest::SHA256.hexdigest(content), filename]
end
CSV.open(File.join(out, 'SCRIPT_MANIFEST.csv'), 'wb') do |csv|
  csv << %w[index script_id script_name source_bytes source_sha256 file]
  rows.each { |r| csv << r }
end
File.write(File.join(out, 'SCRIPTS_RVDATA_SHA256.txt'), "#{Digest::SHA256.file(src).hexdigest}  Scripts.rvdata\n")
puts "exported=#{scripts.size} source=#{src} out=#{out}"
