module DocumentsHelper
  def stage_badge_class(stage)
    case stage
    when 'acquired' then 'secondary'
    when 'categorized' then 'info'
    when 'identified' then 'primary'
    when 'normalized' then 'warning'
    when 'stored' then 'success'
    when 'enriched' then 'dark'
    else 'light'
    end
  end
end
