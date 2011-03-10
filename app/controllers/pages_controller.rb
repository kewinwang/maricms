class PagesController < ApplicationController
  before_filter :get_setting
  theme :get_theme
  
  caches_action :show, :cache_path => Proc.new { |c| c.params }
  
  # GET /pages
  # GET /pages.xml
  def index
    #@pages = Page.all.asc(:position)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @pages }
    end
  end

  def datatable
    @records = current_records(params)
    @total_records = total_records()

    respond_to do |format|
      format.js {render :layout => false}
    end
  end

  # GET /pages/1
  # GET /pages/1.xml
  def show
    begin
      @page = Page.find(:first, :conditions => {:slug => params[:id]}) || Page.find(params[:id])

      begin
        template_content = IO.read(File.join(theme_path, "theme", @page.theme_path ))
      rescue
        template_content = IO.read(File.join(theme_path, "theme", "page_default.html" ))
      end
      template = Liquid::Template.parse(template_content)  # Parses and compiles the template
      #TODO need to cache the template somewhere in future

      #Assemble the variable and it's content, and then pass to template
      render_params = Hash.new
      render_params["params"] = params

      #add the tabs to the template
      # tabs = Array.new
      # Tab.traverse(:depth_first) do |tab|
      #   tabs << tab
      # end
      # render_params["tabs"] = tabs
      # render_params["current_tab"] = @tab

      # Query the datasource based on the parameters
      q = {}
      params.each do |k,v|
        s = k.split(".")
        if s && s.size > 2 && s[0] == "ds"
          q[s[1]] = {s[2] => v}
        end
      end

      r_page_ds = @page.r_page_ds
      if r_page_ds && r_page_ds.size > 0
        for r_page_d in r_page_ds
          d_key = r_page_d.d.key
          unless r_page_d.new_d_name.blank?
            d_key = r_page_d.new_d_name
          end
          if q[d_key].nil?
          render_params[d_key] = r_page_d.default_query.paginate(:page => params[:page], :per_page => @page.per_page || 20)
          else
          render_params[d_key] = r_page_d.default_query.where(q[d_key]).paginate(:page => params[:page], :per_page => @page.per_page || 20)
          end

        end
      end

      respond_to do |format|
        puts render_params
        format.html { render :layout => "front", :text => template.render(render_params, :registers => {:controller => self})}
        format.xml  { render :xml => @page }
      end
    rescue BSON::InvalidObjectId => e
      render :text => "page not found"
    end
  end

  # GET /pages/new
  # GET /pages/new.xml
  def new
    @page = Page.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @page }
    end
  end

  # GET /pages/1/edit
  def edit
    @page = Page.find(:first, :conditions => {:slug => params[:id]}) || Page.find(params[:id])
  end

  # POST /pages
  # POST /pages.xml
  def create
    r_page_ds = params[:page].delete(:r_page_ds)
    @page = Page.new(params[:page])

    if r_page_ds.size > 0

      rpd = []
      r_page_ds.each do |rd|
        unless rd[:d_id].blank?
          r_page_d = RPageD.new(:query_hash => rd[:query_hash])
          r_page_d.d = D.find(rd[:d_id])
          r_page_d.new_d_name = rd[:new_d_name]
          rpd << r_page_d
        end
      end
    @page.r_page_ds = rpd
    end

    respond_to do |format|
      if @page.save
        expire_cache_for_page(@page)
        format.html { redirect_to(@page, :notice => 'Page was successfully created.') }
        format.xml  { render :xml => @page, :status => :created, :location => @page }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @page.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /pages/1
  # PUT /pages/1.xml
  def update
    r_page_ds = params[:page].delete(:r_page_ds)
    @page = Page.find(:first, :conditions => {:slug => params[:id]}) || Page.find(params[:id])

    if r_page_ds.size > 0

      #remove the old ones
      @page.r_page_ds.destroy_all
      # end remove

      rpd = []
      r_page_ds.each do |rd|
        unless rd[:d_id].blank?
          r_page_d = RPageD.new(:query_hash => rd[:query_hash])
          r_page_d.d = D.find(rd[:d_id])
          r_page_d.new_d_name = rd[:new_d_name]
          rpd << r_page_d
        end
      end
    end

    respond_to do |format|
      if @page.update_attributes(params[:page].merge({:r_page_ds => rpd}))
        expire_cache_for_page(@page)
        format.html { redirect_to(@page, :notice => 'Page was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @page.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /pages/1
  # DELETE /pages/1.xml
  def destroy
    @page = Page.find(:first, :conditions => {:slug => params[:id]}) || Page.find(params[:id])
    @page.destroy

    respond_to do |format|
      expire_cache_for_page(@page)
      format.html { redirect_to(pages_url) }
      format.xml  { head :ok }
    end
  end
  
  private
  
  def current_records(params={})
    current_page = (params[:iDisplayStart].to_i/params[:iDisplayLength].to_i rescue 0)+1

    unless params[:sSearch].blank?
      result = Page.any_of(conditions(d))
    else
    result = Page.all
    end
    @total_disp_records_size = result.size

    result.desc(:position).paginate :page => current_page,
    #:include => [:user],
    #:order => "#{datatable_columns(params[:iSortCol_0])} #{params[:sSortDir_0] || "DESC"}",
    :per_page => params[:iDisplayLength]
  end
  
  def total_records
    Page.all.count
  end

  def conditions(d, params={})
    cond = []
    sSearch = params[:sSearch]
    Page.fields.each do |field|
      if  field.last.type == "Integer" && sSearch.to_i.to_s == sSearch
        cond << {"#{field.last.name}".to_sym => sSearch.to_i}
      elsif
        cond << {"#{field.last.name}".to_sym => /#{sSearch}/}
      end
    end
    return cond
  end
  
end
