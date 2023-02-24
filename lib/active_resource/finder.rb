module ActiveResource
  module Finder
    class << self
      def make_order_by_params(order_by)
        case order_by
        when Symbol, String then { order_by => :asc }
        when Array then order_by.index_with{ :asc }
        when NilClass then {}
        else order_by
        end
      end

      def merge_options(*options)
        result_opts = {}.with_indifferent_access
        params = {}.with_indifferent_access
        includes = Set.new
        extra = Set.new
        order_by = {}.with_indifferent_access
        sum = nil

        options.each do |option|
          opt = option.with_indifferent_access
          opt_params = opt.delete(:params) || {}.with_indifferent_access
          includes += Array.wrap(opt.delete(:includes))
          includes += Array.wrap(opt_params.delete(:includes))
          extra += Array.wrap(opt.delete(:extra))
          extra += Array.wrap(opt_params.delete(:extra))
          sum = opt.delete(:sum) || opt_params.delete(:sum)

          opt_order_by = opt.delete(:order_by)
          order_by.update(make_order_by_params(opt_order_by))
          opt_params_order_by = opt_params.delete(:order_by)
          order_by.update(make_order_by_params(opt_params_order_by))

          result_opts.update(opt)
          params.update(opt_params)
        end

        params[:includes] = includes.to_a if includes.present?
        params[:extra] = extra.to_a if extra.present?
        params[:order_by] = order_by if order_by.present?
        params[:sum] = sum if sum
        result_opts[:params] = params
        result_opts
      end
    end

    extend ActiveSupport::Concern

    class_methods do
      def build_find_options(*options)
        merged = Finder.merge_options(*options)
        params = merged.delete(:params) || {}
        build_params!(params)
        merged[:params] = params
        merged
      end

      def build_includes_params!(params)
        incs = []
        Array.wrap(params.delete(:includes)).each do |e|
          incs << e if e.present?
        end
        if incs.present?
          params[:__includes__] = incs.uniq
        end
        params
      end

      def build_extra_params!(params)
        ext_configs = self.schema.extra.select{|k, v| v.options.dig(:extra, :default_request)}.values
        exts = ext_configs.map{|cfg| cfg.server_name}

        param_extra = Array.wrap(params.delete(:extra))
        if param_extra.include?(true)
          exts += self.schema.extra_not_defaults.values.map{|cfg| cfg.server_name}
        else
          param_extra.each do |e|
            if (e_config = self.schema.extra[e])
              exts << e_config.server_name.to_s
            else
              exts << e.to_s
            end
          end
        end
        params[:__extra__] = exts.compact.uniq
        params
      end

      def build_order_by_params!(params)
        order_by = params.delete(:order_by)
        params[:__order_by__] = order_by if order_by.present?
        params
      end

      def build_sum_params!(params)
        sum = params.delete(:sum)
        params[:__invoke__] = {method_name: :sum, args: sum} if sum.present?
        params
      end

      def build_params!(params)
        build_includes_params!(params)
        build_extra_params!(params)
        build_order_by_params!(params)
        build_sum_params!(params)
      end
    end
  end
end