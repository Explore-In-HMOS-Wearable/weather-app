import type Weather from '../model/Interface';
import { SearchCity } from '../view/SearchCity';
import { Temperature } from './Temperature';
import { util } from '@kit.ArkTS';
import { Service } from '../viewmodel/Service';

@Entry
@Component
export struct Index {
  private watchSize: string = '466px';
  private service: Service = Service.getInstance();

  private weatherList: Weather[] = [];
  @State filteredWeatherList: Weather[] = [];
  @State searchText: string = '';
  @State unit: string = 'C';
  @State favoriteIds: string[] = [];
  @State statusMessage: ResourceStr = $r('app.string.status_loading');
  @Provide('NavPathStack') pageStack: NavPathStack = new NavPathStack();

  async aboutToAppear(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      this.statusMessage = $r('app.string.status_context_unavailable');
      return;
    }

    const data = await hostContext.resourceManager.getRawFileContent('weatherData.json');
    const decoder = new util.TextDecoder();
    const jsonStr = decoder.decodeToString(data);
    const mockList = JSON.parse(jsonStr) as Weather[];

    this.weatherList = await this.service.init(hostContext, mockList);
    this.unit = this.service.getUnit();
    this.favoriteIds = this.service.getFavoriteIds();
    this.applyFilter();
  }

  onPageShow(): void {
    if (this.weatherList.length > 0) {
      this.refreshFavoriteState();
    }
  }

  @Builder
  PagesMap(name: string) {
    if (name === 'Temperature') {
      Temperature();
    }
  }

  private applyFilter(): void {
    let list = this.weatherList.slice();

    const query = this.searchText.trim().toLowerCase();
    if (query.length > 0) {
      list = list.filter((item: Weather) => {
        const name = item.name.toLowerCase();
        const station = item.station.toLowerCase();
        const country = item.country.toLowerCase();
        return name.includes(query) || station.includes(query) || country.includes(query);
      });
    }

    this.filteredWeatherList = this.service.sortWeather(list, 'name');
    this.statusMessage = this.searchText.trim().length > 0
      ? $r('app.string.status_cities_found', this.filteredWeatherList.length)
      : $r('app.string.status_tap_city');
  }

  private refreshFavoriteState(): void {
    this.favoriteIds = this.service.getFavoriteIds();
    this.applyFilter();
  }

  private async toggleFavorite(item: Weather): Promise<void> {
    await this.service.toggleFavorite(item.id);
    this.refreshFavoriteState();
  }

  private updateSearch(value: string): void {
    this.searchText = value;
    this.applyFilter();
  }

  @Builder
  private CityRow(item: Weather) {
    Row({ space: 5 }) {
      Image(this.service.isFavorite(item.id) ? $r('app.media.ic_star_on') : $r('app.media.ic_star_off'))
        .width(18)
        .height(18)
        .objectFit(ImageFit.Contain)
        .margin({ right: 2 })
        .onClick(async () => {
          await this.toggleFavorite(item);
      })

      Column() {
        Text(this.service.getShortName(item))
          .fontSize(10)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 4 }) {
          Text(item.country)
            .fontSize(7)
            .fontColor($r('app.color.city_country_text'))
          Text(this.service.formatTemperature(item.temp, this.unit))
            .fontSize(8)
            .fontColor($r('app.color.city_temperature_text'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.pageStack.pushPathByName('Temperature', item);
      })

      Text(item.condition)
        .fontSize(8)
        .fontColor($r('app.color.city_condition_text'))
        .width(44)
        .maxLines(1)
        .textAlign(TextAlign.End)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => {
          this.pageStack.pushPathByName('Temperature', item);
        })
    }
    .width(196)
    .height(42)
    .padding({ left: 9, right: 9 })
    .backgroundColor($r('app.color.city_row_background'))
    .borderRadius(21)
  }

  build() {
    Navigation(this.pageStack) {
      Column({ space: 5 }) {
        Text($r('app.string.weather_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Bolder)
          .fontColor($r('app.color.text_primary'))
          .margin({ top: 28 });

        SearchCity({
          value: this.searchText,
          placeholder: $r('app.string.search_city_code_placeholder'),
          onChanged: (value: string) => {
            this.updateSearch(value);
          }
        })
          .height(30)
          .width('56%');

        List({ space: 5 }) {
          if (this.filteredWeatherList.length > 0) {
            ForEach(this.filteredWeatherList, (item: Weather) => {
              ListItem() {
                this.CityRow(item)
              }
              .width('100%')
            }, (item: Weather) => item.id + this.favoriteIds.length.toString() + this.unit)
          } else {
            ListItem() {
              Text($r('app.string.no_cities_found'))
                .height(42)
                .fontSize(9)
                .fontColor($r('app.color.text_muted'))
                .textAlign(TextAlign.Center)
            }
            .width('100%')
          }
        }
        .width(210)
        .height(250)
        .alignListItem(ListItemAlign.Center)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        Text(this.statusMessage)
          .fontSize(8)
          .fontColor($r('app.color.text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 30, right: 30, bottom: 20 })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('app.color.app_background'));
    }
    .width(this.watchSize)
    .height(this.watchSize)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.PagesMap)
    .hideBackButton(true)
    .ignoreLayoutSafeArea();
  }
}
