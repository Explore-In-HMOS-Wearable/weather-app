import { preferences } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import Weather from '../model/Interface';

const STORE_NAME = 'weather_store';
const FAVORITES_KEY = 'favorites';
const UNIT_KEY = 'unit';
const CACHE_KEY = 'weather_cache';

interface GeocodingResult {
  latitude: number;
  longitude: number;
}

interface GeocodingResponse {
  results?: GeocodingResult[];
}

type OpenMeteoPayload = Record<string, string | number | number[] | undefined>;

interface OpenMeteoCurrent {
  time?: string;
  temperature2m?: number;
  relativeHumidity2m?: number;
  apparentTemperature?: number;
  weatherCode?: number;
  windSpeed10m?: number;
  windDirection10m?: number;
  precipitation?: number;
  cloudCover?: number;
  surfacePressure?: number;
  isDay?: number;
}

interface OpenMeteoDaily {
  uvIndexMax?: number[];
}

interface OpenMeteoCurrentPayload {
  current?: OpenMeteoPayload;
  daily?: OpenMeteoPayload;
}

interface OpenMeteoForecast {
  current?: OpenMeteoCurrent;
  daily?: OpenMeteoDaily;
}

export class Service {
  static instance: Service;

  private store: preferences.Preferences | null = null;
  private favorites: Set<string> = new Set();
  private cache: Map<string, Weather> = new Map();
  private unit: string = 'C';

  static getInstance(): Service {
    if (!Service.instance) {
      Service.instance = new Service();
    }
    return Service.instance;
  }

  async init(context: Context, weatherList: Weather[]): Promise<Weather[]> {
    this.store = await preferences.getPreferences(context, STORE_NAME);
    await this.loadPreferences();
    return this.mergeCache(weatherList);
  }

  getUnit(): string {
    return this.unit;
  }

  async toggleUnit(): Promise<string> {
    this.unit = this.unit === 'C' ? 'F' : 'C';
    await this.saveUnit();
    return this.unit;
  }

  getFavoriteIds(): string[] {
    return Array.from(this.favorites);
  }

  isFavorite(cityId: string): boolean {
    return this.favorites.has(cityId);
  }

  getCachedWeather(cityId: string): Weather | null {
    const cached = this.cache.get(cityId);
    return cached ? cached : null;
  }

  async toggleFavorite(cityId: string): Promise<void> {
    if (this.favorites.has(cityId)) {
      this.favorites.delete(cityId);
    } else {
      this.favorites.add(cityId);
    }
    await this.saveFavorites();
  }

  formatTemperature(value: number, unit: string = this.unit): string {
    const temp = unit === 'F' ? (value * 9 / 5) + 32 : value;
    return `${Math.round(temp)}${unit}`;
  }

  normalizeWeather(raw: Weather): Weather {
    const item = new Weather();
    item.name = raw.name ?? '';
    item.id = raw.id && raw.id.length > 0 ? raw.id : item.name;
    item.temp = raw.temp ?? 0;
    item.station = raw.station && raw.station.length > 0 ? raw.station : this.extractStation(item.name);
    item.country = raw.country && raw.country.length > 0 ? raw.country : this.extractCountry(item.name);
    item.condition = raw.condition && raw.condition.length > 0 ? raw.condition : this.conditionFromTemp(item.temp);
    item.weatherCode = raw.weatherCode ?? 0;
    item.humidity = raw.humidity ?? 0;
    item.windSpeed = raw.windSpeed ?? 0;
    item.windDirection = raw.windDirection ?? 0;
    item.feelsLike = raw.feelsLike ?? item.temp;
    item.precipitation = raw.precipitation ?? 0;
    item.cloudCover = raw.cloudCover ?? 0;
    item.pressure = raw.pressure ?? 0;
    item.isDay = raw.isDay ?? 1;
    item.uvIndex = raw.uvIndex ?? 0;
    item.lastUpdated = raw.lastUpdated && raw.lastUpdated.length > 0 ? raw.lastUpdated : 'Offline sample';
    item.source = raw.source && raw.source.length > 0 ? raw.source : 'mock';
    return item;
  }

  formatWindDirection(degrees: number): string {
    const normalized = ((Math.round(degrees) % 360) + 360) % 360;
    const labels: string[] = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    const index = Math.round(normalized / 45) % 8;
    return `${labels[index]} ${normalized}`;
  }

  formatDecimal(value: number, suffix: string = ''): string {
    return `${Math.round(value * 10) / 10}${suffix}`;
  }

  getShortName(item: Weather): string {
    const station = item.station && item.station.length > 0 ? item.station : this.extractStation(item.name);
    if (station.length <= 22) {
      return station;
    }
    return station.substring(0, 21);
  }

  sortWeather(list: Weather[], sortMode: string): Weather[] {
    const sorted = list.slice();
    sorted.sort((left: Weather, right: Weather) => {
      const favDiff = this.favoriteRank(left) - this.favoriteRank(right);
      if (favDiff !== 0) {
        return favDiff;
      }

      if (sortMode === 'hot') {
        return right.temp - left.temp;
      }
      if (sortMode === 'cold') {
        return left.temp - right.temp;
      }
      return this.getShortName(left).localeCompare(this.getShortName(right));
    });
    return sorted;
  }

  getCountryOptions(list: Weather[], limit: number = 4): string[] {
    const counts: Map<string, number> = new Map();
    for (let i = 0; i < list.length; i++) {
      const country = list[i].country;
      if (country.length === 0 || country === '--') {
        continue;
      }
      counts.set(country, (counts.get(country) ?? 0) + 1);
    }

    const countries = Array.from(counts.keys());
    countries.sort((left: string, right: string) => {
      return (counts.get(right) ?? 0) - (counts.get(left) ?? 0);
    });
    return ['ALL'].concat(countries.slice(0, limit));
  }

  async refreshWeather(city: Weather): Promise<Weather> {
    const query = encodeURIComponent(this.getGeocodingQuery(city));
    const country = city.country.length === 2 && city.country !== '--' ? `&countryCode=${city.country}` : '';
    const geoUrl = `https://geocoding-api.open-meteo.com/v1/search?name=${query}&count=1&language=en&format=json${country}`;
    const geo = await this.getJson(geoUrl) as GeocodingResponse;
    const results = geo.results;
    if (!results || results.length === 0) {
      throw new Error('City was not found by the live weather service.');
    }

    const first = results[0];
    const latitude = first.latitude;
    const longitude = first.longitude;
    const weatherUrl =
      `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}` +
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,' +
        'wind_direction_10m,precipitation,cloud_cover,surface_pressure,is_day' +
        '&daily=uv_index_max&forecast_days=1&timezone=auto';
    const weatherPayload = await this.getJson(weatherUrl) as OpenMeteoCurrentPayload;
    const weather = this.toOpenMeteoForecast(weatherPayload);
    const current: OpenMeteoCurrent = weather.current ?? {};
    const daily = weather.daily;
    const uvValues = daily ? (daily.uvIndexMax ?? []) : [];
    const code = Number(current.weatherCode ?? 0);

    const updated = this.normalizeWeather(city);
    updated.temp = Number(current.temperature2m ?? updated.temp);
    updated.humidity = Number(current.relativeHumidity2m ?? updated.humidity);
    updated.feelsLike = Number(current.apparentTemperature ?? updated.feelsLike);
    updated.windSpeed = Number(current.windSpeed10m ?? updated.windSpeed);
    updated.windDirection = Number(current.windDirection10m ?? updated.windDirection);
    updated.precipitation = Number(current.precipitation ?? updated.precipitation);
    updated.cloudCover = Number(current.cloudCover ?? updated.cloudCover);
    updated.pressure = Number(current.surfacePressure ?? updated.pressure);
    updated.isDay = Number(current.isDay ?? updated.isDay);
    updated.uvIndex = uvValues && uvValues.length > 0 ? Number(uvValues[0]) : 0;
    updated.weatherCode = code;
    updated.condition = this.conditionFromCode(code);
    updated.lastUpdated = current.time ?? updated.lastUpdated;
    updated.source = 'live';

    this.cache.set(updated.id, updated);
    await this.saveCache();
    return updated;
  }

  private async loadPreferences(): Promise<void> {
    if (!this.store) {
      return;
    }

    const favoritesRaw = await this.store.get(FAVORITES_KEY, '[]') as string;
    const favoriteIds = JSON.parse(favoritesRaw) as string[];
    this.favorites = new Set(favoriteIds);

    this.unit = await this.store.get(UNIT_KEY, 'C') as string;

    const cacheRaw = await this.store.get(CACHE_KEY, '[]') as string;
    const cachedList = JSON.parse(cacheRaw) as Weather[];
    this.cache = new Map();
    for (let i = 0; i < cachedList.length; i++) {
      const cached = this.normalizeWeather(cachedList[i]);
      this.cache.set(cached.id, cached);
    }
  }

  private mergeCache(weatherList: Weather[]): Weather[] {
    const merged: Weather[] = [];
    for (let i = 0; i < weatherList.length; i++) {
      const normalized = this.normalizeWeather(weatherList[i]);
      if (!weatherList[i].id || weatherList[i].id.length === 0) {
        normalized.id = `${normalized.name}#${i}`;
      }
      const cached = this.cache.get(normalized.id);
      merged.push(cached ? cached : normalized);
    }
    return merged;
  }

  private async saveFavorites(): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.put(FAVORITES_KEY, JSON.stringify(Array.from(this.favorites)));
    await this.store.flush();
  }

  private async saveUnit(): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.put(UNIT_KEY, this.unit);
    await this.store.flush();
  }

  private async saveCache(): Promise<void> {
    if (!this.store) {
      return;
    }
    await this.store.put(CACHE_KEY, JSON.stringify(Array.from(this.cache.values())));
    await this.store.flush();
  }

  private async getJson(url: string): Promise<object> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 8000,
        readTimeout: 8000
      });
      return JSON.parse(response.result.toString()) as object;
    } finally {
      request.destroy();
    }
  }

  private toOpenMeteoForecast(payload: OpenMeteoCurrentPayload): OpenMeteoForecast {
    const currentPayload: OpenMeteoPayload = payload.current ?? {};
    const dailyPayload: OpenMeteoPayload = payload.daily ?? {};
    return {
      current: {
        time: this.getText(currentPayload, 'time', ''),
        temperature2m: this.getNumber(currentPayload, 'temperature_2m', 0),
        relativeHumidity2m: this.getNumber(currentPayload, 'relative_humidity_2m', 0),
        apparentTemperature: this.getNumber(currentPayload, 'apparent_temperature', 0),
        weatherCode: this.getNumber(currentPayload, 'weather_code', 0),
        windSpeed10m: this.getNumber(currentPayload, 'wind_speed_10m', 0),
        windDirection10m: this.getNumber(currentPayload, 'wind_direction_10m', 0),
        precipitation: this.getNumber(currentPayload, 'precipitation', 0),
        cloudCover: this.getNumber(currentPayload, 'cloud_cover', 0),
        surfacePressure: this.getNumber(currentPayload, 'surface_pressure', 0),
        isDay: this.getNumber(currentPayload, 'is_day', 1)
      },
      daily: {
        uvIndexMax: this.getNumberArray(dailyPayload, 'uv_index_max')
      }
    };
  }

  private getNumber(payload: OpenMeteoPayload, key: string, fallback: number): number {
    const value = payload[key];
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      return Number(value);
    }
    return fallback;
  }

  private getNumberArray(payload: OpenMeteoPayload, key: string): number[] {
    const value = payload[key];
    return Array.isArray(value) ? value : [];
  }

  private getText(payload: OpenMeteoPayload, key: string, fallback: string): string {
    const value = payload[key];
    return typeof value === 'string' ? value : fallback;
  }

  private favoriteRank(item: Weather): number {
    return this.isFavorite(item.id) ? 0 : 1;
  }

  private extractStation(name: string): string {
    const slashIndex = name.indexOf('/');
    const commaIndex = name.indexOf(',');
    let endIndex = commaIndex >= 0 ? commaIndex : name.length;
    if (slashIndex >= 0 && slashIndex < endIndex) {
      endIndex = slashIndex;
    }
    return name.substring(0, endIndex).trim();
  }

  private extractCountry(name: string): string {
    const parts = name.split(',');
    if (parts.length === 0) {
      return '';
    }
    return parts[parts.length - 1].trim();
  }

  private getGeocodingQuery(city: Weather): string {
    const station = this.getShortName(city);
    if (station.length > 0) {
      return station;
    }
    return city.name;
  }

  private conditionFromTemp(temp: number): string {
    if (temp <= 5) {
      return 'Cold';
    }
    if (temp >= 28) {
      return 'Hot';
    }
    if (temp >= 20) {
      return 'Warm';
    }
    return 'Mild';
  }

  private conditionFromCode(code: number): string {
    if (code === 0) {
      return 'Clear';
    }
    if (code === 1 || code === 2 || code === 3) {
      return 'Cloudy';
    }
    if ((code >= 45 && code <= 48) || (code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return 'Rain';
    }
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return 'Snow';
    }
    if (code >= 95) {
      return 'Storm';
    }
    return 'Weather';
  }
}
