export class Service {
  temp: number = 0;
  static instance: Service;

  static getInstance() {
    if (!Service.instance) {
      Service.instance = new Service()
    }
    return Service.instance
  }
}