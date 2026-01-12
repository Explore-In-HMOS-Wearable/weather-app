import { Service } from '../viewmodel/Service'

@Component
export struct Temperature {
  @Consume('NavPathStack') pageStack: NavPathStack;

  build() {
    NavDestination() {
      Column() {
        Text(Service.getInstance().temp.toString() + '°C').width('100%').fontSize(50)
        if (Service.getInstance().temp > 15) {
          Image($r('app.media.sunny')).width(40).height(40)
        } else {
          Image($r('app.media.cold')).width(40).height(40)
        }
        Button('Previous Page').margin({ top: 10 }).width('80%').onClick(() => {
          this.pageStack.pop()
        })
      }.justifyContent(FlexAlign.Center).margin({ top: 50 })
    }
    .backgroundColor(Color.Black)
    .width('100%')
    .width('100%')
    .hideTitleBar(true)
    .hideBackButton(true)
    .mode(NavDestinationMode.STANDARD)
  }
}