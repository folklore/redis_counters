# coding: utf-8
require 'redis_counters/base_counter'
require 'redis_counters/clusterize_and_partitionize'

module RedisCounters

  # Счетчик на основе redis-hash, с возможностью партиционирования и кластеризации значений.

  class HashCounter < BaseCounter
    include ClusterizeAndPartitionize

    alias_method :increment, :process

    protected

    def process_value
      redis.hincrbyfloat(key, field, params.fetch(:value, 1.0))
    end

    def field
      if group_keys.present?
        group_params = group_keys.map { |key| params.fetch(key) }
      else
        group_params = [field_name]
      end

      group_params.join(value_delimiter)
    end

    def field_name
      @field_name ||= options.fetch(:field_name)
    end

    def group_keys
      @group_keys ||= Array.wrap(options.fetch(:group_keys, []))
    end

    # Protected: Возвращает данные партиции в виде массива хешей.
    #
    # Каждый элемент массива, представлен в виде хеша, содержащего все параметры кластеризации и
    # значение счетчика в ключе :value.
    #
    # cluster - Array - листовой кластер - массив параметров однозначно идентифицирующий кластер.
    # partition - Array - листовая партиция - массив параметров однозначно идентифицирующий партицию.
    #
    # Returns Array of WithIndifferentAccess.
    #
    def partition_data(cluster, partition)
      keys = group_keys.dup.unshift(:value)
      redis.hgetall(key(partition, cluster)).inject(Array.new) do |result, (key, value)|
        values = key.split(value_delimiter, -1).unshift(format_value(value))
        values.delete_at(1) unless group_keys.present?
        result << Hash[keys.zip(values)].with_indifferent_access
      end
    end

    def format_value(value)
      if float_mode?
        value.to_f
      else
        value.to_i
      end
    end

    def float_mode?
      @float_mode ||= options.fetch(:float_mode, false)
    end
  end

end
