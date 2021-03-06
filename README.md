# Coupons

Coupons is a Rails engine for creating discount coupons.

## 安装过程
1.Gemfile:

```ruby
gem 'coupons', github: 'zhaoxinxi/coupons'
```

You also need one pagination library. You can choose between [paginate](https://github.com/fnando/paginate) or [kaminari](https://github.com/amatsuda/kaminari), so make sure one of these libs is added to your Gemfile as well.
需要这两个gem中任选一个，但我实作用kaminari不行，回头再试试。
```ruby
gem 'paginate'  貌似只能用这个，但请注意这个gem和will_paginate有冲突，我直接删了will_paginate，回头有空再试试。
# or
gem 'kaminari'  这个貌似是不行。
```
终端

    $ bundle


2.config/routes.rb加入下面这行

```ruby
mount Coupons::Engine => '/', as: 'coupons_engine'
```
终端

    $ rake routes
重启server

3.建db
    
    
    $ rake coupons:install:migrations
    $ rake db:migrate

然后应该就可以进localhost:3000/coupons页面了。
You can visit `/coupons` to access the dashboard.

我按JDstore的设计修改了coupon和application这两个controller实现了admin权限验证。如果要用在别的项目上，这两个需要自己再改。

原gem有以下的坑：gem获取地址，rails5.0不支持，db初始栏位有错，自动rake的bug，部署环境限制，自己加admin验证，will_paginate冲突。这些问题有的在原帖的issue和pull request里，有的是自己蒙着解得，有兴趣的同学可以从头摸索一下，保证非常有趣，各种酸爽😂

原作地址https://github.com/fnando/coupons

现在这版基本可以叫JDstore专版了，应该不用再调了，装完玩一玩就可以开始在JDstore的结算进行设计应用了，开工。

下面的内容是这个gem的各种说明，玩的愉快。


## Creating coupons

There are two types of coupons: percentage or amount.

- **percentage**: applies the percentage discount to total amount.
- **amount**: applies the amount discount to the total amount.

### Defining the coupon code format

The coupon code is generated with `Coupons.configuration.generator`. By default, it creates a 6-chars long uppercased alpha-numeric code. You can use any object that implements the `call` method and returns a string. The following implementation generates coupon codes like `AWESOME-B7CB`.

```ruby
Coupons.configure do |config|
  config.generator = proc do
    token = SecureRandom.hex[0, 4].upcase
    "AWESOME-#{token}"
  end
end
```

You can always override the generated coupon code through the dashboard or Ruby.

### Working with coupons

Imagine that you created the coupon `RAILSCONF15` as a $100 discount; you can apply it to any amount using the `Coupons.apply` method. Notice that this method won't redeem the coupon code and it's supposed to be used on the checkout page.

```ruby
Coupons.apply('RAILSCONF15', amount: 600.00)
#=> {:amount => 600.0, :discount => 100.0, :total => 500.0}
```

When a coupon is invalid/non-redeemable, it returns the discount amount as `0`.

```ruby
Coupons.apply('invalid', amount: 100.00)
#=> {:amount => 100.0, :discount => 0, :total => 100.0}
```

To redeem the coupon you can use `Coupon.redeem`.

```ruby
Coupons.redeem('RAILSCONF15', amount: 600.00)
#=> {:amount => 600.0, :discount => 100.0, :total => 500.0}

coupon = Coupons::Models::Coupon.last

coupon.redemptions_count
#=> 1

coupon.redemptions
#=> [#<Coupons::Models::CouponRedemption:0x0000010e388290>]
```

### Defining the coupon finder strategy

By default, the first redeemable coupon is used. You can set any of the following strategies.

- `Coupons::Finders::FirstAvailable`: returns the first redeemable coupon available.
- `Coupons::Finders::SmallerDiscount`: returns the smaller redeemable discount available.
- `Coupons::Finders::LargerDiscount`: returns the larger redeemable discount available.

To define a different strategy, set the `Coupons.configurable.finder` attribute.

```ruby
Coupons.configure do |config|
  config.finder = Coupons::Finders::SmallerDiscount
end
```

A finder can be any object that receives the coupon code and the options (which must include the `amount` key). Here's how the smaller discount finder is implemented.

```ruby
module Coupons
  module Finders
    SmallerDiscount = proc do |code, options = {}|
      coupons = Models::Coupon.where(code: code).all.select(&:redeemable?)

      coupons.min do |a, b|
        a = a.apply(options)
        b = b.apply(options)

        a[:discount] <=> b[:discount]
      end
    end
  end
end
```

#### Injecting helper methods

The whole coupon interaction can be made through some helpers methods. You can extend any object with `Coupons::Helpers` module. So do it in your initializer file or in your controller, whatever suits you best.

```ruby
coupons = Object.new.extend(Coupons::Helpers)
```

Now you can do all the interactions through the `coupons` variable.

### Authorizing access to the dashboard

Coupons has a flexible authorization system, meaning you can do whatever you want. All you have to do is defining the authorization strategy by setting `Coupons.configuration.authorizer`. By default, it disables access to the `production` environment, as you can see below.

```ruby
Coupons.configure do |config|
  config.authorizer = proc do |controller|
    if Rails.env.production?
      controller.render(
        text: 'Coupons: not enabled in production environments',
        status: 403
      )
    end
  end
end
```

To define your own strategy, like doing basic authentication, you can do something like this:

```ruby
Coupons.configure do |config|
  config.authorizer = proc do |controller|
    controller.authenticate_or_request_with_http_basic do |user, password|
      user == 'admin' && password == 'sekret'
    end
  end
end
```

### Attaching coupons to given records

To be written.

### Creating complex discount rules

To be written.

### JSON endpoint

You may want to apply discounts using AJAX, so you can give instant feedback. In this case, you'll find the `/coupons/apply` endpoint useful.

```javascript
var response = $.get('/coupons/apply', {amount: 600.0, coupon: 'RAILSCONF15'});
response.done(function(options)) {
  console.log(options);
  //=> {amount: 600.0, discount: 100.0, total: 500.0}
});
```

If you provide invalid amount/coupon, then it'll return zero values, like `{amount: 0, discount: 0, total: 0}`.

### I18n support

Coupons uses [I18n](http://guides.rubyonrails.org/i18n.html). It has support for `en` and `pt-BR`. You can contribute with your language by translating the file [config/en.yml](https://github.com/fnando/coupons/blob/master/config/locale/en.yml).

## Screenshots

![Viewing existing coupons](https://github.com/fnando/coupons/raw/master/screenshots/coupons-index.png)

![Creating coupon](https://github.com/fnando/coupons/raw/master/screenshots/coupons-new.png)

## Contributing

1. Before implementing anything, create an issue to discuss your idea. This only applies to big changes and new features.
2. Fork it ( https://github.com/fnando/coupons/fork )
3. Create your feature branch (`git checkout -b my-new-feature`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request
