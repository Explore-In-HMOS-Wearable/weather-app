import { weatherData } from "../model/Interface";
import Weather from "../model/Interface";
import { Service } from "../viewmodel/Service"
import { ArcList, ArcListItem, ArcListAttribute, ArcListItemAttribute, router, LengthMetrics } from '@kit.ArkUI';
import { SearchCity } from "../view/SearchCity";

@Entry
@Component
export struct Index {
  private watchSize: string = '466px'
  private listSize: string = '420px'
  placeholder: string = "Search City"

  build() {
    Column() {
      Text("CITY LIST").fontSize(20).fontWeight(FontWeight.Bolder).margin({ top: 20 })
      SearchCity().height('15%').width('90%')
      ArcList({ initialIndex: 0 }) {
        ForEach(weatherData, (item: Weather) => {
          ArcListItem() {
            Button() {
              Temp({
                name: item.name
              })
            }.onClick(() => {
              Service.getInstance().temp = item.temp
              router.pushUrl({ url: "pages/Temperature" })
            })
          }.align(Alignment.Center)
        }, (item: Weather) => JSON.stringify(item))
      }.width(this.listSize).height('90%').space(LengthMetrics.px(10))
    }.justifyContent(FlexAlign.Center)
    .width(this.watchSize)
    .height(this.watchSize)
  }
}

@Component
struct Temp {
  name: string = '';

  build() {
    Column() {
      Text(this.name)
        .width('90%')
        .height(40)
        .margin(5)
    }
  }
}