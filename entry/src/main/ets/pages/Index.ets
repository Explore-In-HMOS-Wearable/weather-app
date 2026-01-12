import type Weather from '../model/Interface';
import { ArcList, ArcListItem, ArcListAttribute, ArcListItemAttribute, LengthMetrics } from '@kit.ArkUI';
import { SearchCity } from '../view/SearchCity';
import { Temperature } from './Temperature';
import { util } from '@kit.ArkTS';

@Entry
@Component
export struct Index {
  private watchSize: string = '466px';
  private listSize: string = '420px';
  context: UIContext = this.getUIContext();

  @State weatherList: Weather[] = [];
  @Provide('NavPathStack') pageStack: NavPathStack = new NavPathStack();

  async aboutToAppear() {
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      return;
    }

    const data = await hostContext.resourceManager.getRawFileContent(
      'weatherData.json'
    );

    const decoder = new util.TextDecoder();
    const jsonStr = decoder.decodeToString(data);
    this.weatherList = JSON.parse(jsonStr) as Weather[];
  }

  @Builder
  PagesMap(name: string) {
    if (name === 'Temperature') {
      Temperature();
    }
  }

  build() {
    Navigation(this.pageStack) {
      Column() {
        Text('CITY LIST')
          .fontSize(20)
          .fontWeight(FontWeight.Bolder)
          .margin({ top: 20 });

        SearchCity().height('15%').width('90%');

        ArcList({ initialIndex: 0 }) {
          ForEach(this.weatherList, (item: Weather) => {
            ArcListItem() {
              Button() {
                Temp({ name: item.name });
              }
              .onClick(() => {
                this.pageStack.pushPathByName('Temperature', item);
              });
            }.align(Alignment.Center);
          }, (item: Weather) => item.name)
        }
        .width(this.listSize)
        .height('90%')
        .space(LengthMetrics.px(10));
      }
      .justifyContent(FlexAlign.Center);
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

@Component
struct Temp {
  name: string = '';

  build() {
    Text(this.name)
      .width('90%')
      .height(40)
      .margin(5);
  }
}
