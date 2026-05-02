@Component
export struct SearchCity {
  value: string = '';
  placeholder: ResourceStr = $r('app.string.search_city_placeholder');
  onChanged: (value: string) => void = () => {};

  build() {
    TextInput({ placeholder: this.placeholder, text: this.value })
      .height(30)
      .width('100%')
      .backgroundColor($r('app.color.search_background'))
      .placeholderColor($r('app.color.text_muted'))
      .placeholderFont({ size: 9 })
      .fontColor($r('app.color.text_primary'))
      .fontSize(9)
      .borderRadius(15)
      .padding({ left: 12, right: 12 })
      .onChange((value: string) => {
        this.onChanged(value);
      })
  }
}
