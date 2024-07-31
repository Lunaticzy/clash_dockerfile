#!/usr/bin/env ruby
require 'yaml'

# 从命令行参数获取配置文件路径
config_file_path = ARGV[0]
unless config_file_path
  abort "No configuration file path provided."
end

# 加载 YAML 文件
config_data = YAML.load_file(config_file_path)

# 从环境变量中获取需要的值
external_bind = ENV['EXTERNAL_BIND']
external_port = ENV['EXTERNAL_PORT']
external_secret = ENV['EXTERNAL_SECRET']

# 更新配置数据
if external_bind && !external_port.nil?
  config_data['external-controller'] = "#{external_bind}:#{external_port}"
end
config_data['secret'] = external_secret if external_secret

# 改变 port 的 key 而不是 value
if config_data.key?('port')
  mixed_port_value = config_data['port'] # 先保存 port 的值
  config_data['mixed-port'] = mixed_port_value # 然后使用新的 key
  config_data.delete('port') # 删除旧的 key
end

# 其他配置更新
config_data['external-ui'] = '/root/ui'
config_data['ipv6'] = false
config_data['allow-lan'] = true

# 写入更新后的配置数据到文件
File.write(config_file_path, config_data.to_yaml)