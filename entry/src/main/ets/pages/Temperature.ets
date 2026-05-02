import Weather from '../model/Interface';
import { Service } from '../viewmodel/Service';
import {
  ArcDirection,
  ArcDotIndicator,
  ArcSwiper,
  ArcSwiperAttribute,
  ArcSwiperController,
  CircleShape
} from '@kit.ArkUI';

@Component
export struct Temperature {
  private service: Service = Service.getInstance();
  private wearableSwiperController: ArcSwiperController = new ArcSwiperController();

  @Consume('NavPathStack') pageStack: NavPathStack;
  @State weather: Weather = new Weather();
  @State unit: string = 'C';
  @State favorite: boolean = false;
  @State refreshState: ResourceStr = $r('app.string.status_updating');
  @State refreshing: boolean = false;
  @State activePage: number = 0;

  private async refreshLiveWeather(): Promise<void> {
    if (this.refreshing) {
      return;
    }

    this.refreshing = true;
    this.refreshState = $r('app.string.status_updating');
    try {
      this.weather = await this.service.refreshWeather(this.weather);
      this.refreshState = $r('app.string.status_live_weather');
    } catch (err) {
      const cached = this.service.getCachedWeather(this.weather.id);
      if (cached) {
        this.weather = cached;
      }
      this.refreshState = $r('app.string.status_using_cached_data');
    }
    this.refreshing = false;
  }

  private async toggleFavorite(): Promise<void> {
    this.favorite = !this.favorite;
    await this.service.toggleFavorite(this.weather.id);
    this.favorite = this.service.isFavorite(this.weather.id);
  }

  private async toggleUnit(): Promise<void> {
    this.unit = await this.service.toggleUnit();
  }

  private getDayNightLabel(): ResourceStr {
    return this.weather.isDay === 1 ? $r('app.string.label_day') : $r('app.string.label_night');
  }

  private getUvLabel(): ResourceStr {
    if (this.weather.uvIndex < 3) {
      return $r('app.string.uv_low');
    }
    if (this.weather.uvIndex < 6) {
      return $r('app.string.uv_moderate');
    }
    if (this.weather.uvIndex < 8) {
      return $r('app.string.uv_high');
    }
    return $r('app.string.uv_very_high');
  }

  @Builder
  private BackButton() {
    Button({ type: ButtonType.Circle }) {
      Image($r('app.media.ic_back'))
        .width(16)
        .height(16)
        .objectFit(ImageFit.Contain)
    }
    .width(26)
    .height(26)
    .backgroundColor($r('app.color.control_background'))
    .onClick(() => {
      this.pageStack.pop();
    })
  }

  @Builder
  private FavoriteButton() {
    Button({ type: ButtonType.Circle }) {
      Image(this.favorite ? $r('app.media.ic_star_on') : $r('app.media.ic_star_off'))
        .width(17)
        .height(17)
        .objectFit(ImageFit.Contain)
    }
    .width(26)
    .height(26)
    .backgroundColor($r('app.color.control_background'))
    .onClick(async () => {
      await this.toggleFavorite();
    })
  }

  @Builder
  private WeatherIcon(size: number) {
    if (this.weather.condition === 'Clear' || this.weather.condition === 'Warm' || this.weather.condition === 'Hot') {
      Image($r('app.media.sunny')).width(size).height(size)
    } else if (this.weather.condition === 'Cold' || this.weather.condition === 'Snow') {
      Image($r('app.media.cold')).width(size).height(size)
    } else {
      Image($r('app.media.cloudy')).width(size).height(size)
    }
  }

  @Builder
  private MetricTile(label: ResourceStr, value: ResourceStr, accent: ResourceColor) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(accent)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label)
        .fontSize(7)
        .fontColor($r('app.color.city_country_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(74)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.metric_tile_background'))
    .borderRadius(8)
  }

  @Builder
  private HeroPage() {
    Column({ space: 5 }) {
      this.WeatherIcon(40)
      Text(this.service.formatTemperature(this.weather.temp, this.unit))
        .width('100%')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.toggleUnit();
        })
      Text(this.service.getShortName(this.weather))
        .fontSize(11)
        .fontColor($r('app.color.text_primary'))
        .width('78%')
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 3 }) {
        Text(this.weather.condition)
          .fontSize(8)
          .fontColor($r('app.color.weather_accent'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text($r('app.string.condition_separator'))
          .fontSize(8)
          .fontColor($r('app.color.weather_accent'))
        Text(this.getDayNightLabel())
          .fontSize(8)
          .fontColor($r('app.color.weather_accent'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private FeelPage() {
    Column({ space: 6 }) {
      Text($r('app.string.section_comfort'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Row({ space: 5 }) {
        this.MetricTile($r('app.string.metric_feels'), this.service.formatTemperature(this.weather.feelsLike, this.unit), $r('app.color.accent_feels'))
        this.MetricTile($r('app.string.metric_humidity'), $r('app.string.percent_value', Math.round(this.weather.humidity)), $r('app.color.weather_accent'))
      }
      Row({ space: 5 }) {
        this.MetricTile($r('app.string.metric_clouds'), $r('app.string.percent_value', Math.round(this.weather.cloudCover)), $r('app.color.accent_clouds'))
        this.MetricTile($r('app.string.metric_pressure'), `${Math.round(this.weather.pressure)}`, $r('app.color.accent_pressure'))
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private WindRainPage() {
    Column({ space: 6 }) {
      Text($r('app.string.section_wind_rain'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Row({ space: 5 }) {
        this.MetricTile($r('app.string.metric_wind'), $r('app.string.wind_speed_value', Math.round(this.weather.windSpeed)), $r('app.color.accent_wind'))
        this.MetricTile($r('app.string.metric_direction'), this.service.formatWindDirection(this.weather.windDirection), $r('app.color.accent_direction'))
      }
      Row({ space: 5 }) {
        this.MetricTile($r('app.string.metric_rain'), $r('app.string.precipitation_value', this.service.formatDecimal(this.weather.precipitation)), $r('app.color.accent_rain'))
        this.MetricTile($r('app.string.metric_code'), `${Math.round(this.weather.weatherCode)}`, $r('app.color.accent_code'))
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private SunPage() {
    Column({ space: 6 }) {
      Text($r('app.string.section_sun'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Row({ space: 5 }) {
        this.MetricTile($r('app.string.metric_uv'), this.service.formatDecimal(this.weather.uvIndex), $r('app.color.accent_uv'))
        this.MetricTile($r('app.string.metric_risk'), this.getUvLabel(), $r('app.color.accent_risk'))
      }
      Row({ space: 5 }) {
        this.MetricTile($r('app.string.metric_light'), this.getDayNightLabel(), $r('app.color.accent_light'))
        this.MetricTile($r('app.string.metric_source'), this.weather.source, $r('app.color.accent_source'))
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        Progress({
          value: this.activePage + 1,
          total: 4,
          type: ProgressType.Ring
        })
          .aspectRatio(1)
          .width('100%')
          .color($r('app.color.weather_accent'))
          .backgroundColor($r('app.color.progress_track'))
          .style({ strokeWidth: 7 })

        ArcSwiper(this.wearableSwiperController) {
          this.HeroPage()
          this.FeelPage()
          this.WindRainPage()
          this.SunPage()
        }
        .clipShape(new CircleShape({ width: 258, height: 258 }))
        .effectMode(EdgeEffect.Spring)
        .vertical(false)
        .duration(350)
        .indicator(
          new ArcDotIndicator()
            .arcDirection(ArcDirection.SIX_CLOCK_DIRECTION)
            .selectedItemColor($r('app.color.weather_accent'))
            .itemColor($r('app.color.indicator_inactive'))
        )
        .onChange((index: number) => {
          this.activePage = index;
        })
        .width(258)
        .height(258)
        .align(Alignment.Center)
        .digitalCrownSensitivity(CrownSensitivity.MEDIUM)

        Column() {
          Row() {
            this.BackButton()
            Blank()
            this.FavoriteButton()
          }
          .width('44%')
          .height(26)
          .margin({ top: 40 })
        }
        .width('100%')
        .height(80)
        .alignItems(HorizontalAlign.Center)
        .position({ x: 0, y: 0 })
        .zIndex(2)

        Column({ space: 2 }) {
          Row({ space: 5 }) {
            Text($r('app.string.page_indicator', this.activePage + 1, 4))
              .fontSize(8)
              .fontColor($r('app.color.weather_accent'))
            Text(this.refreshState)
              .fontSize(8)
              .fontColor($r('app.color.text_muted'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .justifyContent(FlexAlign.Center)

          Text(this.weather.lastUpdated)
            .fontSize(7)
            .fontColor($r('app.color.text_dim'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('70%')
        .height(32)
        .alignItems(HorizontalAlign.Center)
        .position({ x: 70, y: 382 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.app_background'))
    }
    .onReady((ctx: NavDestinationContext) => {
      this.pageStack = ctx.pathStack;
      const params = ctx.pathInfo.param as Weather;
      if (params) {
        this.weather = this.service.normalizeWeather(params);
        this.favorite = this.service.isFavorite(this.weather.id);
      }
      this.unit = this.service.getUnit();
      this.refreshLiveWeather();
    })
    .hideTitleBar(true)
    .hideBackButton(true)
    .mode(NavDestinationMode.STANDARD)
  }
}
