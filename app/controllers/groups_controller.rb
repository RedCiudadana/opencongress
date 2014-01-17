class GroupsController < ApplicationController
  before_filter :login_required, :except => [ :show, :index ]
  before_filter :check_membership, :only => :show

  respond_to :html, :json, :xml
  respond_to :js, :only => [:index]

  def new
    @page_title = 'Create a New OpenCongress Group'
    @group = Group.new
    @group.join_type = 'ANYONE'
    @group.invite_type = 'ANYONE'
    @group.post_type = 'ANYONE'
  end

  def create
    @group = Group.new(params[:group])
    @group.user = current_user

    respond_to do |format|
      if @group.save_with_captcha
        format.html { redirect_to(new_group_group_invite_path(@group, :new => true), :notice => 'Group was successfully created.') }
        format.xml  { render :xml => @group, :status => :created, :location => @group }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  def show
    # we got the @group object in check_membership
    if not @group.user.is_banned?
      @simple_comments = true
      @page_title = "#{@group.name} - MyOC Groups"
      respond_with(@group) do |format|
        format.xml { redirect_to feed_group_political_notebook_notebook_items_path(@group) }
      end
    else
      flash[:notice] = "The #{@group.name} group has been disabled because its creator was banned."
      redirect_to(:action => 'index') and return
    end
  end

  def index
    @page_title = 'OpenCongress Groups'
    @page = params.fetch(:page, 1).to_i
    @page = 1 unless @page > 0

    unless params[:sort].blank?
      sort_column, sort_dir = params[:sort].split

      sort_dir = (sort_dir == 'DESC') ? 'DESC' : 'ASC'
      case sort_column
      when 'name'
        @sort = "groups.name #{sort_dir}"
      when 'issue_area'
        @sort = "subjects.term #{sort_dir}, groups.name ASC"
      when 'group_members'
        @sort = "group_members_count #{sort_dir}"
      else
        @sort = "groups.name #{sort_dir}"
      end
    else
      @sort = 'groups.state_id DESC, groups.district_id DESC, groups.name ASC'
      # @sort = 'group_members_count DESC, groups.state_id DESC, groups.district_id DESC, groups.name ASC'
    end

    if params[:state]
      @state = State.find_by_abbreviation(params[:state])
      @groups = Group.in_state(@state.id).order("groups.state_id, groups.name ASC")
      @page_title = "OpenCongress Groups in #{@state.name}"
    else
      @groups = Group.visible.order(@sort)
    end

    unless params[:q].blank?
      # Here we just grab the group ids from elasticsearch and manually
      # fetch the models below.
      groups_found = Group.search(params[:q], :per_page => 20, :page => @page)
      @groups = Group.where(:id => groups_found.map(&:id))
    end

    unless params[:subject].blank?
      @groups = @groups.where(:subject_id => params[:subject])
    end

    @groups = @groups.select("groups.*, coalesce(gm.group_members_count, 0) as group_members_count").joins(%q{LEFT OUTER JOIN (select group_id, count(group_members.*) as group_members_count from group_members where status != 'BOOTED' group by group_id) gm ON (groups.id=gm.group_id)}).includes(:subject).paginate(:per_page => 20, :page => @page)

    respond_with @groups
  end

  def edit
    @page_title = "Edit Group Settings"
    @group = Group.find(params[:id])

    unless ((@group.user == current_user) or admin_logged_in?)
      redirect_to groups_path, :notice => "You are not that group's owner, so you can't edit settings!"
      return
    end
  end

  def update
    @group = Group.find(params[:id])

    respond_to do |format|
      if @group.update_attributes(params[:group])
        format.html { redirect_to(@group, :notice => 'Group settings were successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @group = Group.find(params[:id])

    unless @group.is_owner?(current_user) or admin_logged_in?
      redirect_to groups_path, :notice => "You don't have permission to do that!"
      return
    end

    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_path, :notice => 'Group successfully deleted!') }
    end
  end

  private

  def check_membership
    @group = Group.find(params[:id])
    if @group.nil?
      redirect_to groups_path
      return
    end

    if !@group.publicly_visible?
      if current_user == :false
        redirect_to groups_path, :notice => "That group is private!"
        return
      else
        return true if @group.user == current_user

        membership = @group.group_members.where(["group_members.user_id=?", current_user.id]).first

        if membership.nil?
          redirect_to groups_path, :notice => "That group is private!"
          return
        elsif membership.status == 'BOOTED'
          redirect_to groups_path, :notice => "You have been booted from that group."
          return
        end
      end
    end

    if current_user == :false
      @last_view = Time.now
    else
      membership = @group.group_members.where(:group_members => { :user_id => current_user.id}).first

      if membership.nil?
        @last_view = Time.now
      else
        @last_view = membership.last_view
        membership.last_view = Time.now
        membership.save
      end
    end
  end
end
