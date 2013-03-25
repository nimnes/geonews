class NewsController < ApplicationController
    def index
        @total = FeedEntry.all.count
        if params[:category].nil?
            @news = FeedEntry.where("category IS NULL").paginate(page: params[:page], per_page: 50)
        else
            if params[:category] == "global"
                @news = FeedEntry.where("category = 'global'").paginate(page: params[:page], per_page: 50)
            end

            if params[:category] == "local"
                @news = FeedEntry.where("category != 'global'").paginate(page: params[:page], per_page: 50)
            end

            if params[:category] == "predicted"
                @news = FeedEntry.where("category = 'predicted'").paginate(page: params[:page], per_page: 50)
            end
        end
    end

    # PUT /news/1
    # PUT /news/1.json
    def update
        @entry = FeedEntry.find(params[:id])

        tags = params["tags" + params[:id]]

        respond_to do |format|
            if FeedEntry.add_tag(@entry, tags)
                format.html {render action: "index"}
                format.json {head :no_content}
            else
                format.html {render action: "index"}
                format.json {render json: @entry.errors, status: :unprocessable_entity}
            end
        end
    end
end
