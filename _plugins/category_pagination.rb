module Jekyll
  class Post
    alias_method :original_next, :next
    def next
      if self.data.has_key?('paginate_next')
        self.data['paginate_next']
      else
        original_next
      end
    end

    alias_method :original_previous, :previous
    def previous
      if self.data.has_key?('paginate_previous')
        self.data['paginate_previous']
      else
        original_previous
      end
    end
  end

  module Generators
    class CategoryPagination < Generator
      def generate(site)
        site.pages.dup.each do |page|
          paginate(site, page) if CategoryPager.pagination_enabled?(site, page)
        end
      end

      def paginate(site, target)
        all_posts = site.site_payload['site']['posts']
        if !target.data['category'].nil?
          category = target.data['category']
          all_posts = all_posts.select do |post|
            post.data['category'] == category
          end
        end
        pages = CategoryPager.calculate_pages(all_posts, target.data['paginate'].to_i)
        (1..pages).each do |num_page|
          pager = CategoryPager.new(target, num_page, all_posts, pages)
          if num_page > 1
            newpage = Page.new(site, site.source, target.dir, target.name)
            newpage.pager = pager
            newpage.dir = CategoryPager.paginate_path(target, num_page)
            site.pages << newpage
          else
            target.pager = pager
          end
        end
        all_posts.sort!
        (0...all_posts.length).each do |pos|
          post = all_posts[pos]
          if pos > 0
            post.data['paginate_previous'] = all_posts[pos-1]
          else
            post.data['paginate_previous'] = nil
          end
          if pos < all_posts.length-1
            post.data['paginate_next'] = all_posts[pos+1]
          else
            post.data['paginate_next'] = nil
          end
        end
      end
    end
  end

  class CategoryPager
    attr_reader :page, :per_page, :posts, :total_posts, :total_pages,
      :previous_page, :previous_page_path, :next_page, :next_page_path,
      :first_page_path, :last_page_path

    def self.calculate_pages(all_posts, per_page)
      (all_posts.size.to_f / per_page.to_i).ceil
    end

    def self.pagination_enabled?(site, page)
      !page.data['paginate'].nil? and page.name == 'index.html'
    end

    def self.paginate_path(target, num_page)
      return nil if num_page.nil?
      return target.url if num_page <= 1
      format = target.data['paginate_path']
      format = format.sub(':num', num_page.to_s)
      ensure_leading_slash(format)
    end

    def self.ensure_leading_slash(path)
      path[0..0] == "/" ? path : "/#{path}"
    end

    def initialize(target, page, all_posts, num_pages = nil)
      @page = page
      @per_page = target.data['paginate'].to_i
      @total_pages = num_pages || CategoryPager.calculate_pages(all_posts, @per_page)

      if @page > @total_pages
        raise RuntimeError, "page number can't be greater than total pages: #{@page} > #{@total_pages}"
      end

      init = (@page - 1) * @per_page
      offset = (init + @per_page - 1) >= all_posts.size ? all_posts.size : (init + @per_page - 1)

      @total_posts = all_posts.size
      @posts = all_posts[init..offset]
      @previous_page = @page != 1 ? @page - 1 : nil
      @previous_page_path = CategoryPager.paginate_path(target, @previous_page)
      @next_page = @page != @total_pages ? @page + 1 : nil
      @next_page_path = CategoryPager.paginate_path(target, @next_page)
      @first_page_path = CategoryPager.paginate_path(target, 1)
      @last_page_path = CategoryPager.paginate_path(target, @total_pages)
    end

    def to_liquid
      {
        'page' => page,
        'per_page' => per_page,
        'posts' => posts,
        'total_posts' => total_posts,
        'total_pages' => total_pages,
        'previous_page' => previous_page,
        'previous_page_path' => previous_page_path,
        'next_page' => next_page,
        'next_page_path' => next_page_path,
        'first_page_path' => first_page_path,
        'last_page_path' => last_page_path
      }
    end
  end
end
