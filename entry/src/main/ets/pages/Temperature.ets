import { router } from "@kit.ArkUI";
import { Service } from "../viewmodel/Service"

@Entry
@Component
struct Temperature {
  build() {
    Column() {
      Text(Service.getInstance().temp.toString() + "°C").width('100%').fontSize(50)
      if (Service.getInstance().temp > 15) {
        Image($r('app.media.sunny')).width(40).height(40)
      } else {
        Image($r('app.media.cold')).width(40).height(40)
      }
      Button("Previous Page").margin({ top: 10 }).width('80%').onClick(() => {
        router.back()
      })
    }.justifyContent(FlexAlign.Center).margin({ top: 50 })
  }
}