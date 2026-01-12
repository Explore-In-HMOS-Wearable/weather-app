@Component
export struct SearchCity {
  placeholder: string = 'Search City'

  build() {
    Search({ placeholder: this.placeholder }).height('80%')
  }
}